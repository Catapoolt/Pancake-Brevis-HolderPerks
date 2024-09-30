package wallet_out_Cake

import (
	"fmt"
	"github.com/brevis-network/brevis-sdk/sdk"
	"github.com/ethereum/go-ethereum/common"
)

type WalletOutCakeCircuit struct{}

var _ sdk.AppCircuit = &WalletOutCakeCircuit{}

var cake = sdk.ConstUint248(common.HexToAddress("0xD3677F083B127a93c825d015FcA7DD0e45684AcA"))
var zero = sdk.ConstUint248(0)

func (c *WalletOutCakeCircuit) Allocate() (maxReceipts, maxStorage, maxTransactions int) {
	// Receipts and Transactions need to be equal
	return 10, 0, 0
}

func (c *WalletOutCakeCircuit) Define(api *sdk.CircuitAPI, in sdk.DataInput) error {
	receipts := sdk.NewDataStream(api, in.Receipts)

	fmt.Print("Receipts: ")
	fmt.Println(sdk.Count(receipts))

	sdk.AssertEach(receipts, func(cur sdk.Receipt) sdk.Uint248 {
		return api.Uint248.And(
			api.Uint248.IsEqual(cur.Fields[0].Contract, cake),
			api.Uint248.IsEqual(cur.Fields[1].Contract, cake),
		)
	})

	// todo: we assume each receipt fields[0] is wallet id and fields[1] is the amount
	walletAddress := api.ToUint248(sdk.GetUnderlying(receipts, 0).Fields[0].Value)
	amount := sdk.Reduce(receipts, zero, func(accumulator sdk.Uint248, current sdk.Receipt) (newAccumulator sdk.Uint248) {
		fmt.Print("Wallet address: ")
		fmt.Println(current.Fields[0].Value.String())
		fmt.Print("Wallet amount: ")
		fmt.Println(current.Fields[1].Value.String())
		return api.Uint248.Add(accumulator, api.ToUint248(current.Fields[1].Value))
	})

	fmt.Print("Final wallet address: ")
	fmt.Println(walletAddress.String())
	fmt.Print("Final wallet amount: ")
	fmt.Println(amount.String())

	api.OutputAddress(walletAddress)
	api.OutputUint(248, amount)

	return nil
}
