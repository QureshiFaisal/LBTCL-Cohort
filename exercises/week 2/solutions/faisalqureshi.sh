
GREEN='\033[32m'
ORANGE='\033[35m'
NC='\033[0m'


download_bitcoin_core(){

wget https://bitcoincore.org/bin/bitcoin-core-25.0/bitcoin-25.0-x86_64-apple-darwin.dmg
wget https://bitcoincore.org/bin/bitcoin-core-25.0/SHA256SUMS.asc
wget https://bitcoincore.org/bin/bitcoin-core-25.0/SHA256SUMS
}



verify_binary_signatures(){
VERSION="25.0"
DMG_FILE="bitcoin-${VERSION}-x86_64-apple-darwin.dmg"
CHECKSUMS_FILE="SHA256SUMS"
SIGNATURE_FILE="SHA256SUMS.asc"
gpg --keyserver keyserver.ubuntu.com --recv-keys 01EA5486DE18A882D4C2684590C8019E36C2E964
gpg --verify "${SIGNATURE_FILE}"

if shasum -a 256 -c "${CHECKSUMS_FILE}" 2>/dev/null | grep -q "${DMG_FILE}: OK"; then
    echo "✅ Binary signature verification successful! Happy verifying! 😃"
else
    echo "❌ Binary signature verification unsuccessful! Please check the integrity of your binary. 😞"
fi
}




create_conf_file() {
    echo "**************************************"
	echo -e "${ORANGE}Creating bitcoin.conf file${NC}"
    echo "**************************************"
	cd /Users/$USER/Library/Application\ Support/Bitcoin

	# Create a file called bitcoin.conf
	touch bitcoin.conf

	echo "regtest=1" >> bitcoin.conf
	echo "fallbackfee=0.0001" >> bitcoin.conf
	echo "server=1" >> bitcoin.conf
	echo "txindex=1" >> bitcoin.conf
}


delete_regtest_dir() {
    echo "**************************************"
	echo -e "${ORANGE}Deleting regtest directory if exists${NC}"
    echo "**************************************"
	if [ -d "/Users/$USER/Library/Application\ Support/Bitcoin/regtest" ]; then
		rm -rf /Users/$USER/Library/Application\ Support/Bitcoin/regtest
	fi
}

start_bitcoind() {
    echo "**************************************"
	echo -e "${ORANGE}Starting bitcoind${NC}"
    echo "**************************************"
	# Start bitcoind in the background
	bitcoind -daemon
	# Wait for 10 seconds
	sleep 10
	# Now you can run bitcoin-cli getinfo
	bitcoin-cli -getinfo
}



create_wallets() {
echo "**************************************"
echo -e "${ORANGE}Creating two wallets${NC}"
echo "**************************************"

    # Check if Miner wallet exists
    if bitcoin-cli  -rpcwallet=Miner getwalletinfo >/dev/null 2>&1; then
        bitcoin-cli   -rpcwallet=Miner loadwallet "Miner" 2>/dev/null
    else
        bitcoin-cli  createwallet "Miner"
        bitcoin-cli  -rpcwallet=Miner loadwallet "Miner" 2>/dev/null
    fi

    # Check if Trader wallet exists
    if bitcoin-cli -rpcwallet=Trader getwalletinfo >/dev/null 2>&1; then
        bitcoin-cli -rpcwallet=Trader loadwallet "Trader" 2>/dev/null
    else
        bitcoin-cli  createwallet "Trader"
        bitcoin-cli  -rpcwallet=Trader loadwallet "Trader" 2>/dev/null
    fi
    echo "**************************************"
    echo -e "${ORANGE}Trader and Miner wallets are ready${NC}"
    echo "**************************************"
}





generate_miner_address_and_mine_blocks() {

echo "**************************************"
echo -e "${ORANGE}Generating blocks for Miner wallet${NC}"
echo "**************************************"

    miner_address=$(bitcoin-cli  -rpcwallet="Miner" getnewaddress "Mining Reward")
    bitcoin-cli  -rpcwallet="Miner" generatetoaddress 104 $miner_address
    original_balance=$(bitcoin-cli  -rpcwallet="Miner" getbalance)

    # Check if the balance is equal to or greater than 150 BTC
    if (( $(echo "$original_balance >= 150" | bc -l) )); then
        echo -e "${GREEN}Miner wallet funded with at least 3 block rewards worth of satoshis (Starting balance: ${original_balance} BTC).${NC}"
    else
        echo -e "${ORANGE}Miner wallet balance is less than 150 BTC (Starting balance: ${original_balance} BTC).${NC}"
    fi
}



generate_trader_address() {
    trader_address=$(bitcoin-cli  -rpcwallet=Trader getnewaddress "Received")
      echo -e "${ORANGE}Trader address generated.${NC}"
}


extract_unspent_outputs(){
unspent_outputs=$(bitcoin-cli   -rpcwallet=Miner listunspent 0)

# Extract the txid values of the first and second UTXOs using pure Bash
    txid1=$(echo "$unspent_outputs" | grep -oE '"txid": "[^"]+"' | awk -F'"' '{print $4}' | sed -n 1p)
    txid2=$(echo "$unspent_outputs" | grep -oE '"txid": "[^"]+"' | awk -F'"' '{print $4}' | sed -n 2p)

 # Print the txid values to verify
    echo -e "${GREEN}First UTXO's txid: $txid1${NC}"
    echo -e "${GREEN}Second UTXO's txid: $txid2${NC}"
}



create_parent_tx() {
    # Create the raw transaction
    rawtx_parent=$(bitcoin-cli  -rpcwallet=Miner createrawtransaction '[
        {
            "txid": "'$txid1'",
            "vout": 0
        },
        {
            "txid": "'$txid2'",
            "vout": 0
        }
    ]' '{
        "'$trader_address'": 70.0,
        "'$miner_address'": 29.99999
    }')

    # Sign the raw transaction with the wallet
    output=$(bitcoin-cli  -rpcwallet=Miner signrawtransactionwithwallet "$rawtx_parent")

    # Extract the signed raw transaction
    signed_rawtx_parent=$(echo "$output" | grep -oE '"hex": "[^"]+"' | awk -F'"' '{print $4}')

    # Send the signed raw transaction and get the parent_txid
    parent_txid=$(bitcoin-cli  -rpcwallet=Miner sendrawtransaction "$signed_rawtx_parent")

    echo -e "${GREEN}Parent Transaction ID: ${parent_txid}"
}




create_child_tx(){
child_raw_tx=$(bitcoin-cli  -rpcwallet=Miner createrawtransaction "[
        {
            \"txid\": \"$parent_txid\",
            \"vout\": 1
        }
    ]" "{
        \"$miner_address\": 29.99998
    }")
output_child=$(bitcoin-cli  -rpcwallet=Miner signrawtransactionwithwallet "$child_raw_tx")
  signed_rawtx_child=$(echo "$output_child" | grep -oE '"hex": "[^"]+"' | awk -F'"' '{print $4}')
 child_txid=$(bitcoin-cli  -rpcwallet=Miner sendrawtransaction "$signed_rawtx_child")
 echo -e "${GREEN}Child Transaction ID: $child_txid${NC}"
}

query_child()
{
child_query1=$(bitcoin-cli  -rpcwallet=Miner getmempoolentry $child_txid)

}

bump_parent_tx() {
    # Create the raw transaction
    rawtx_parent=$(bitcoin-cli -rpcwallet=Miner createrawtransaction '[
        {
            "txid": "'$txid1'",
            "vout": 0
        },
        {
            "txid": "'$txid2'",
            "vout": 0
        }
    ]' '{
        "'$trader_address'": 70.0,
        "'$miner_address'": 29.99989
    }')

    # Sign the raw transaction with the wallet
    output2=$(bitcoin-cli -rpcwallet=Miner signrawtransactionwithwallet "$rawtx_parent")

    # Extract the signed raw transaction
    signed_rawtx_parent=$(echo "$output2" | grep -oE '"hex": "[^"]+"' | awk -F'"' '{print $4}')

    # Send the signed raw transaction and get the parent_txid
    parent_txid=$(bitcoin-cli -rpcwallet=Miner sendrawtransaction "$signed_rawtx_parent")

    echo "Parent Transaction ID after fee bump: ${parent_txid}"
}




query_child2()
{
child_query1=$(bitcoin-cli  -rpcwallet=Miner getmempoolentry $child_txid)

}


download_bitcoin_core
verify_binary_signatures
create_conf_file
delete_regtest_dir
start_bitcoind
create_wallets
generate_miner_address_and_mine_blocks
generate_trader_address
extract_unspent_outputs
create_parent_tx
create_child_tx
query_child
bump_parent_tx
query_child2


: '
After the fee of the parent transaction is bumped the output states that the child transaction is not in the mempool.
The reason seems to be that the parent transaction that it depended upon has now been replaced, and that invalidates the child transaction. Guys, do let me know if anyone else reached the same inference.
'

print_parent_info(){

parent_txid=$(bitcoin-cli -rpcwallet=Trader listtransactions | jq -r '.[0] | .txid')
  rawt_tx=$(bitcoin-cli -rpcwallet=Trader gettransaction $parent_txid| jq -r '.hex')
    parent_input_txid=($(bitcoin-cli decoderawtransaction $raw_tx | jq -r '.vin | .[] | .txid'))
   parent_input_vout=($(bitcoin-cli decoderawtransaction $raw_tx | jq -r '.vin | .[] | .vout'))
  parent_output_amount=($(bitcoin-cli decoderawtransaction $raw_tx | jq -r '.vout | .[] | .value'))
  parent_output_spubkey=($(bitcoin-cli decoderawtransaction $raw_tx | jq -r '.vout | .[] | .scriptPubKey.hex'))
    fees=$(bitcoin-cli -rpcwallet=Trader getmempoolentry $parent_txid | jq -r '.fees.base')
   weight=$(bitcoin-cli -rpcwallet=Trader getmempoolentry $parent_txid | jq -r '.weight')

#    echo "Parent txid: $parent_txid"
#    echo "Parent input txid 1: ${parent_input_txid[0]}" 
#    echo "Parent input txid 2: ${parent_input_txid[1]}"
#    echo "Parent input vout 1: ${parent_input_vout[0]}" 
#    echo "Parent input vout 2: ${parent_input_vout[1]}"
#    echo "Parent output 1 amount: ${parent_output_amount[0]} BTC"
#    echo "Parent output 2 amount: ${ parent_output_amount[1]} BTC"
#    echo "Trader scriptPubKey: ${parent_output_spubkey[0]}"
#    echo "Miner change scriptPubKey: ${ parent_output_spubkey[1]}"      
#    echo "Parent transaction fees: $fees BTC"
#    echo "Parent transaction weight: $((weight/4)) vbytes"



  JSON='{
      "input": [
        {
          "txid": "'${parent_input_txid[0]}'",
          "vout": "'${parent_input_vout[0]}'"
        },
        {
          "txid": "'${parent_input_txid[1]}'",
          "vout": "'${parent_input_vout[1]}'"
        }
      ],
      "output": [
        {
          "script_pubkey": "'${parent_output_spubkey[1]}'",
          "amount": "'${parent_output_amount[1]}'"
        },
        {
          "script_pubkey": "'${parent_output_spubkey[0]}'",
          "amount": "'${parent_output_amount[0]}'"
        }
      ],
      "Fees": "'$fees'",
      "Weight": "'$weight' (weight of the tx in vbytes)"
    }'

    # Print the JSON to the terminal
    echo $JSON
}


# executing functions


print_parent_info
