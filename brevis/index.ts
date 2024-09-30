import {Brevis, ErrCode, Prover} from 'brevis-sdk-typescript';
import {proof_request_transfers_from_wallet} from "./indexer";

async function main() {
  const prover = new Prover('localhost:32001');
  // const brevis = new Brevis('appsdkv2.brevis.network:9094');

  // const apiKey = "TEST_ACCOUNT_AGE_KEY"
  // const callbackAddress = "0x075A43436D0F6460dD4A40ea8C67D7165C621A2E"

  const proofReq = await proof_request_transfers_from_wallet()

  const proofRes = await prover.prove(proofReq);
  // error handling
  if (proofRes.has_err) {
    const err = proofRes.err;
    switch (err.code) {
      case ErrCode.ERROR_INVALID_INPUT:
        console.error('invalid receipt/storage/transaction input:', err.msg);
        break;

      case ErrCode.ERROR_INVALID_CUSTOM_INPUT:
        console.error('invalid custom input:', err.msg);
        break;

      case ErrCode.ERROR_FAILED_TO_PROVE:
        console.error('failed to prove:', err.msg);
        break;
    }
    return;
  }
  console.log('proof', proofRes.proof);

  // try {
  //   const brevisRes = await brevis.submit(proofReq, proofRes, 97, 97, 0, apiKey, callbackAddress);
  //   console.log('brevis res', brevisRes);
  //
  //   await brevis.wait(brevisRes.queryKey, 97);
  // } catch (err) {
  //   console.error(err);
  // }
}

main().then(() => console.log("Finished main!"));
