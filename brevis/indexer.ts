import {GoldRushClient, LogEvent, Param} from "@covalenthq/client-sdk";
import {Field, ProofRequest, ReceiptData} from "brevis-sdk-typescript";

const transferTopicHash = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
const targetCoin = "0xD3677F083B127a93c825d015FcA7DD0e45684AcA" // bsc-testnet Cake 3 Token (CAKE3)

async function get_transfers_from_wallet(walletId: string, startingBlock: number): Promise<LogEvent[]> {
  const client = new GoldRushClient("cqt_rQ4B9bxHBDmvKCgcDG3fXBhDFpWm"); // todo: move this to config

  // todo: make blockchain configurable
  const logEvents = client.BaseService.getLogEventsByTopicHash("bsc-testnet", transferTopicHash, {
    startingBlock: startingBlock,
    endingBlock: "latest",
    secondaryTopics: walletId
  })

  const valid_events: LogEvent[] = []
  for await (const event of logEvents) {
    for (let item of event.data.items) {
      console.log(item)
      console.log(item.decoded.params)
      // interested only in BNB transaction from walletId
      if (item.sender_address.toLowerCase() == targetCoin.toLowerCase()) {
        const match = item.decoded.params.filter((param: Param) => param.name.toLowerCase() == "from" && param.value.toLowerCase() == walletId.toLowerCase())
        if (match.length == 1) {
          valid_events.push(item)
        }
      }
    }
  }

  return valid_events
}

export async function proof_request_transfers_from_wallet(): Promise<ProofRequest> {
  const proofReq = new ProofRequest();

  const log_events = await get_transfers_from_wallet("0xb83A3061D0D34073ACcbDA25b32c4c62caff4529", 44301000);

  for (let log_index = 0; log_index < log_events.length; log_index++) {
    const log = log_events[log_index];

    const log_fields: Field[] = []
    for (let i = 0; i < log.decoded.params.length; i++) {
      const param = log.decoded.params[i];
      if (param.name == "from") {
        const field = new Field({
          contract: log.sender_address,
          log_index: 0, // todo: if this is not the case, we need its transaction to calculate its position from there
          event_id: transferTopicHash,
          is_topic: true,
          field_index: i,
          value: param.value,
        })

        log_fields.push(field)
      }
      if (param.name == "value") {
        const field = new Field({
          contract: log.sender_address,
          log_index: 0, // todo: if this is not the case, we need its transaction to calculate its position from there
          event_id: transferTopicHash,
          is_topic: false,
          field_index: i,
          value: param.value,
        })

        log_fields.push(field)
      }
    }

    let receiptData = new ReceiptData({
      block_num: log.block_height,
      tx_hash: log.tx_hash,
      fields: log_fields,
    });

    console.log("ReceiptData: ", JSON.stringify(receiptData.toObject()));
    proofReq.addReceipt(
      receiptData,
      log_index
    );
  }

  let receipts_number = proofReq.getReceipts().length;
  console.log(`Found ${receipts_number} receipts!`);

  return proofReq
}
