# Synchronization

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 35. OFFLINE COLLABORATION

Users can continue editing offline.

Each device stores:
- local operations
- snapshots
- pending operations

When peers reconnect:
- exchange missing operations
- verify signatures
- decrypt
- merge
- create consistent state

## 36. ASSET COLLABORATION

Assets identified by content hash.

Example:
SHA-256(asset bytes)

If peer already has asset:
- do not transfer again

If not:
- transfer encrypted chunks

Support:
- resumable transfers
- integrity verification
- duplicate elimination
- chunk hashing
- compression where useful

## 61. NETWORK FAILURE

When connection drops:
- continue local editing
- queue operations
- show offline state
- retry
- synchronize when connection returns

Never discard unsynchronized work.
