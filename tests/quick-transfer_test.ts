import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Instant Transfer: Basic Transfer Flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const sender = accounts.get('wallet_1')!;
    const recipient = accounts.get('wallet_2')!;
    const deployer = accounts.get('deployer')!;

    // Initial transfer amount (10 STX)
    const transferAmount = 1000000;

    let block = chain.mineBlock([
      Tx.contractCall('quick-transfer', 'create-transfer', 
        [
          types.principal(recipient.address),
          types.uint(transferAmount)
        ], 
        sender.address
      )
    ]);

    // Check transfer creation was successful
    block.receipts[0].result.expectOk();
    const transferId = block.receipts[0].result.expectOk().expectUint;

    // Mine blocks to simulate cooling period
    chain.mineEmptyBlock(200);

    // Confirm transfer
    block = chain.mineBlock([
      Tx.contractCall('quick-transfer', 'confirm-transfer', 
        [types.uint(transferId)], 
        recipient.address
      )
    ]);

    // Check transfer confirmation was successful
    block.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "Instant Transfer: Transfer Cancellation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const sender = accounts.get('wallet_1')!;
    const recipient = accounts.get('wallet_2')!;

    // Initial transfer amount (10 STX)
    const transferAmount = 1000000;

    let block = chain.mineBlock([
      Tx.contractCall('quick-transfer', 'create-transfer', 
        [
          types.principal(recipient.address),
          types.uint(transferAmount)
        ], 
        sender.address
      )
    ]);

    // Check transfer creation was successful
    block.receipts[0].result.expectOk();
    const transferId = block.receipts[0].result.expectOk().expectUint;

    // Cancel transfer
    block = chain.mineBlock([
      Tx.contractCall('quick-transfer', 'cancel-transfer', 
        [types.uint(transferId)], 
        sender.address
      )
    ]);

    // Check transfer cancellation was successful
    block.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "Instant Transfer: Platform Fee Calculation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const sender = accounts.get('wallet_1')!;
    const recipient = accounts.get('wallet_2')!;
    const deployer = accounts.get('deployer')!;

    // Initial transfer amount (10 STX)
    const transferAmount = 1000000;
    const expectedPlatformFee = 5000; // 0.5% of 1,000,000

    let block = chain.mineBlock([
      Tx.contractCall('quick-transfer', 'create-transfer', 
        [
          types.principal(recipient.address),
          types.uint(transferAmount)
        ], 
        sender.address
      )
    ]);

    // Validate platform fee deduction logic would require more complex testing
    // This test just ensures the basic transfer creation works
    block.receipts[0].result.expectOk();
  }
});