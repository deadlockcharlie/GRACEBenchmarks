import * as Y from "yjs";
import { logger } from "./logging";
import { REPLICA_ID, PEER_REPLICA_ID, DATACENTER_ID, PEER_DC_ID, ACK_LEVEL, AckLevel } from "../app";

export type AckRecord = {
  operation: string;
  operationId: string;
  timestamp: number;
  replicaId: string;
  localAcked: boolean;  // acknowledged by peer replica within the same DC
  dcAcked: boolean;     // acknowledged by a replica in the peer DC
};

export class PeerAcknowledgmentSystem {
  private ydoc: Y.Doc;
  private acks: Y.Map<AckRecord>;
  private pendingAcks: Map<string, { resolve: () => void; reject: (err: Error) => void; timeout: NodeJS.Timeout; ackLevel: AckLevel }>;

  constructor(ydoc: Y.Doc) {
    this.ydoc = ydoc;
    this.acks = ydoc.getMap("PeerAcknowledgments");
    this.pendingAcks = new Map();
    logger.info(`[PeerAck] Initializing for REPLICA_ID=${REPLICA_ID}, PEER_REPLICA_ID=${PEER_REPLICA_ID}, PEER_DC_ID=${PEER_DC_ID}, ACK_LEVEL=${ACK_LEVEL}`);
    this.setupObserver();
  }

  private setupObserver() {
    this.acks.observe((event, transaction) => {
      logger.info(`[PeerAck] Observer fired, local=${transaction.local}, changes=${event.changes.keys.size}`);
      if (!transaction.local) {
        event.changes.keys.forEach((change, key) => {
          logger.info(`[PeerAck] Processing change: key=${key}, action=${change.action}`);
          if (change.action === "add" || change.action === "update") {
            const ackRecord = this.acks.get(key);
            logger.info(`[PeerAck] AckRecord: ${JSON.stringify(ackRecord)}`);
            if (ackRecord) {
              // Check if this is an update to one of our own pending operations
              if (key.startsWith(REPLICA_ID)) {
                const pending = this.pendingAcks.get(key);
                if (pending) {
                  const satisfied = this.isAckSatisfied(ackRecord, pending.ackLevel);
                  logger.info(`[PeerAck] Own operation ${key}: localAcked=${ackRecord.localAcked}, dcAcked=${ackRecord.dcAcked}, ackLevel=${pending.ackLevel}, satisfied=${satisfied}`);
                  if (satisfied) {
                    logger.info(`[PeerAck] All required acks received for ${key}`);
                    this.handlePeerAcknowledgment(key);
                  }
                }
              }
              // Check if this is an operation from our local peer that needs a local ack
              else if (!ackRecord.localAcked && ackRecord.replicaId === PEER_REPLICA_ID) {
                logger.info(`[PeerAck] Received operation ${key} from local peer ${PEER_REPLICA_ID}, sending local ack`);
                this.acknowledgeOperation(key, 'local');
              }
              // Check if this is an operation from the peer DC that needs a DC ack
              else if (!ackRecord.dcAcked && PEER_DC_ID !== 'none' && ackRecord.replicaId.startsWith(PEER_DC_ID + '-')) {
                logger.info(`[PeerAck] Received operation ${key} from peer DC ${PEER_DC_ID}, sending DC ack`);
                this.acknowledgeOperation(key, 'dc');
              } else {
                logger.info(`[PeerAck] No action needed: localAcked=${ackRecord.localAcked}, dcAcked=${ackRecord.dcAcked}, replicaId=${ackRecord.replicaId}`);
              }
            }
          }
        });
      }
    });
    logger.info(`[PeerAck] Observer setup complete`);
  }

  private handlePeerAcknowledgment(operationId: string) {
    const pending = this.pendingAcks.get(operationId);
    if (pending) {
      clearTimeout(pending.timeout);
      pending.resolve();
      this.pendingAcks.delete(operationId);
      logger.info(`Received acknowledgment from peer for operation ${operationId}`);
    }
  }

  /**
   * Returns true when the ackRecord satisfies the required ack level.
   */
  private isAckSatisfied(ackRecord: AckRecord, level: AckLevel): boolean {
    switch (level) {
      case "none": return true;
      case "peer": return ackRecord.localAcked;
      case "dc":   return ackRecord.dcAcked;
      case "both": return ackRecord.localAcked && ackRecord.dcAcked;
    }
  }

  /**
   * Register an operation and wait for peer acknowledgment.
   * The required ack level is driven by the ACK_LEVEL env var:
   *   "none" — resolve immediately, no acks needed
   *   "peer" — wait for local (same-DC) peer ack only
   *   "dc"   — wait for cross-DC peer ack only
   *   "both" — wait for both local and cross-DC peer acks
   * @param operation - Type of operation (addVertex, addEdge, etc.)
   * @param operationData - Data associated with the operation
   * @param timeoutMs - Timeout in milliseconds (default 5000)
   */
  async waitForPeerAck(
    operation: string,
    operationData: any,
    timeoutMs: number = 5000
  ): Promise<void> {
    if (ACK_LEVEL === "none") {
      logger.info(`[PeerAck] ACK_LEVEL=none, skipping acknowledgment for ${operation}`);
      return;
    }
    if ((ACK_LEVEL === "peer" || ACK_LEVEL === "both") && (PEER_REPLICA_ID === "none" || PEER_REPLICA_ID === REPLICA_ID)) {
      logger.warn(`[PeerAck] ACK_LEVEL=${ACK_LEVEL} requires a local peer but PEER_REPLICA_ID=${PEER_REPLICA_ID}, skipping`);
      return;
    }
    if ((ACK_LEVEL === "dc" || ACK_LEVEL === "both") && (PEER_DC_ID === "none" || PEER_DC_ID === DATACENTER_ID)) {
      logger.warn(`[PeerAck] ACK_LEVEL=${ACK_LEVEL} requires a peer DC but PEER_DC_ID=${PEER_DC_ID}, skipping`);
      return;
    }

    logger.info(`[PeerAck] waitForPeerAck: operation=${operation}, ACK_LEVEL=${ACK_LEVEL}`);

    const operationId = `${REPLICA_ID}-${operation}-${Date.now()}-${Math.random()}`;

    const ackRecord: AckRecord = {
      operation,
      operationId,
      timestamp: Date.now(),
      replicaId: REPLICA_ID,
      localAcked: false,
      dcAcked: false,
    };

    // Register in Yjs (this will sync to peers)
    this.acks.set(operationId, ackRecord);

    return new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        const current = this.acks.get(operationId);
        this.pendingAcks.delete(operationId);
        logger.warn(`Timeout waiting for acks for ${operationId}: localAcked=${current?.localAcked}, dcAcked=${current?.dcAcked}, required=${ACK_LEVEL}`);
        reject(new Error(`Peer acknowledgment timeout for operation ${operationId}`));
      }, timeoutMs);

      this.pendingAcks.set(operationId, { resolve, reject, timeout, ackLevel: ACK_LEVEL });
    });
  }

  /**
   * Acknowledge a peer's operation.
   * @param ackType - 'local' when acknowledging a same-DC peer; 'dc' when acknowledging a cross-DC peer.
   */
  acknowledgeOperation(operationId: string, ackType: 'local' | 'dc') {
    const ackRecord = this.acks.get(operationId);
    if (!ackRecord) return;
    if (ackType === 'local' && !ackRecord.localAcked) {
      this.acks.set(operationId, { ...ackRecord, localAcked: true });
      logger.info(`[PeerAck] Local-acked operation ${operationId}`);
    } else if (ackType === 'dc' && !ackRecord.dcAcked) {
      this.acks.set(operationId, { ...ackRecord, dcAcked: true });
      logger.info(`[PeerAck] DC-acked operation ${operationId}`);
    }
  }

  /**
   * Process incoming operations from peer and acknowledge them
   * This should be called by the graph observers when they detect peer operations
   */
  setupOperationAcknowledgment() {
    // When we receive operations from our peer (detected in graph observers),
    // we need to acknowledge them
    logger.info(`Setting up operation acknowledgment for peer ${PEER_REPLICA_ID}`);
  }
}
