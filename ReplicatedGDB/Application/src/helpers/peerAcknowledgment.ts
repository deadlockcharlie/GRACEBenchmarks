import * as Y from "yjs";
import { logger } from "./logging";
import { REPLICA_ID, PEER_REPLICA_ID, DATACENTER_ID } from "../app";

export type AckRecord = {
  operation: string;
  operationId: string;
  timestamp: number;
  replicaId: string;
  acknowledged: boolean;
};

export class PeerAcknowledgmentSystem {
  private ydoc: Y.Doc;
  private acks: Y.Map<AckRecord>;
  private pendingAcks: Map<string, { resolve: () => void; reject: (err: Error) => void; timeout: NodeJS.Timeout }>;

  constructor(ydoc: Y.Doc) {
    this.ydoc = ydoc;
    this.acks = ydoc.getMap("PeerAcknowledgments");
    this.pendingAcks = new Map();
    logger.info(`[PeerAck] Initializing for REPLICA_ID=${REPLICA_ID}, PEER_REPLICA_ID=${PEER_REPLICA_ID}`);
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
              // Check if this is an acknowledgment from our peer for our operation
              if (ackRecord.acknowledged && key.startsWith(REPLICA_ID)) {
                logger.info(`[PeerAck] Handling acknowledgment for our operation ${key}`);
                this.handlePeerAcknowledgment(key);
              }
              // Check if this is a new operation from our peer that needs acknowledgment
              else if (!ackRecord.acknowledged && ackRecord.replicaId === PEER_REPLICA_ID) {
                logger.info(`[PeerAck] Received operation ${key} from peer ${PEER_REPLICA_ID}, sending acknowledgment`);
                this.acknowledgeOperation(key);
              } else {
                logger.info(`[PeerAck] No action needed: acknowledged=${ackRecord.acknowledged}, replicaId=${ackRecord.replicaId}, PEER=${PEER_REPLICA_ID}, startsWithMe=${key.startsWith(REPLICA_ID)}`);
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
   * Register an operation and wait for peer acknowledgment
   * @param operation - Type of operation (addVertex, addEdge, etc.)
   * @param operationData - Data associated with the operation
   * @param timeoutMs - Timeout in milliseconds (default 5000)
   */
  async waitForPeerAck(
    operation: string,
    operationData: any,
    timeoutMs: number = 5000
  ): Promise<void> {
    // Skip if there's no peer (single replica per DC)
    if (PEER_REPLICA_ID === "none" || PEER_REPLICA_ID === REPLICA_ID) {
      logger.info(`No peer replica configured, skipping acknowledgment for ${operation}`);
      return Promise.resolve();
    }

    const operationId = `${REPLICA_ID}-${operation}-${Date.now()}-${Math.random()}`;
    
    // Create acknowledgment record
    const ackRecord: AckRecord = {
      operation,
      operationId,
      timestamp: Date.now(),
      replicaId: REPLICA_ID,
      acknowledged: false,
    };

    // Register in Yjs (this will sync to peer)
    this.acks.set(operationId, ackRecord);

    // Wait for peer to acknowledge
    return new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingAcks.delete(operationId);
        logger.warn(`Timeout waiting for peer acknowledgment for ${operationId}`);
        reject(new Error(`Peer acknowledgment timeout for operation ${operationId}`));
      }, timeoutMs);

      this.pendingAcks.set(operationId, { resolve, reject, timeout });
    });
  }

  /**
   * Acknowledge a peer's operation
   * Called when we receive and successfully process a peer's operation
   */
  acknowledgeOperation(operationId: string) {
    const ackRecord = this.acks.get(operationId);
    if (ackRecord && !ackRecord.acknowledged) {
      // Update the record to mark as acknowledged
      const updatedRecord: AckRecord = {
        ...ackRecord,
        acknowledged: true,
      };
      this.acks.set(operationId, updatedRecord);
      logger.info(`Acknowledged operation ${operationId} from peer`);
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
