package main

import (
	"circuits/wallet_out_Cake"
	"github.com/brevis-network/brevis-sdk/sdk/prover"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"os"
)

func main() {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix

	proverService, err := prover.NewService(&wallet_out_Cake.WalletOutCakeCircuit{}, prover.ServiceConfig{
		SetupDir: "$HOME/circuitOut",
		SrsDir:   "$HOME/kzgsrs",
	})
	if err != nil {
		log.Error().Err(err).Msg("could not create prover service")
		os.Exit(1)
	}
	const port uint = 32001
	log.Info().Msgf("starting prover service on port: %d", port)
	proverService.Serve("0.0.0.0", port)
}
