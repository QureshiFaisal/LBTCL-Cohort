

GREEN='\033[32m'
ORANGE='\033[35m'
NC='\033[0m'


#Downloading Bitcoin core, binaries and signatures

wget https://bitcoincore.org/bin/bitcoin-core-25.0/bitcoin-25.0-x86_64-apple-darwin.dmg
wget https://bitcoincore.org/bin/bitcoin-core-25.0/SHA256SUMS.asc
wget https://bitcoincore.org/bin/bitcoin-core-25.0/SHA256SUMS

#Verifying the binaries and signatures

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


cd /Users/$USER/Library/Application\ Support/Bitcoin

touch bitcoin.conf

echo "regtest=1" >> bitcoin.conf
echo "fallbackfee=0.0001" >> bitcoin.conf
echo "server=1" >> bitcoin.conf
echo "txindex=1" >> bitcoin.conf

# Start bitcoind in the background
  bitcoind -daemon
  # Wait for 10 seconds
  sleep 10
  # Now you can run bitcoin-cli getinfo
  bitcoin-cli -getinfo


create_wallets() {
    # Check if Miner wallet exists
    if bitcoin-cli   -rpcwallet=Miner getwalletinfo >/dev/null 2>&1; then
        bitcoin-cli     -rpcwallet=Miner loadwallet "Miner" 2>/dev/null
    else
        bitcoin-cli    createwallet "Miner"
        bitcoin-cli  -rpcwallet=Miner loadwallet "Miner" 2>/dev/null
    fi

    # Check if Trader wallet exists
    if bitcoin-cli  -rpcwallet=Trader getwalletinfo >/dev/null 2>&1; then
        bitcoin-cli   -rpcwallet=Trader loadwallet "Trader" 2>/dev/null
    else
        bitcoin-cli   createwallet "Trader"
        bitcoin-cli  -rpcwallet=Trader loadwallet "Trader" 2>/dev/null
    fi
    echo "**************************************"
    echo -e "${GREEN}Trader and Miner wallets are ready${NC}"
    echo "**************************************"
}

generate_miner_address_and_mine_blocks() {

echo "**************************************"
echo -e "${GREEN}Generating blocks for Miner wallet${NC}"
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

echo "**************************************"
echo -e "${GREEN}Generating trader address${NC}"
echo "**************************************"

    trader_address=$(bitcoin-cli  -rpcwallet=Trader getnewaddress "Received")
}

send_amount(){
# sending 20 BTC from Miner wallet to Trader wallet
txid=$(bitcoin-cli   -rpcwallet=Miner sendtoaddress $trader_address 20)

}

get_mempool(){

# fetching the unconfirmed transaction
bitcoin-cli  getmempoolentry $txid

}

confirm_transaction(){

  # confirming the transaction by creating 1 more block
bitcoin-cli -rpcwallet=Miner -generate 1
}

print_info() {
    transaction_info=$(bitcoin-cli -rpcwallet=Miner gettransaction $txid)
    blockheight=$(echo "$transaction_info" | awk -F'"blockheight": ' '{print $2}' | awk -F, '{print $1}')
    fees_paid=$(echo "scale=8; $amount * -1" | bc)  # Calculate fees_paid as the absolute value of amount
    amount=$(echo "$transaction_info" | grep -o '"amount": -[0-9.]\+' | awk -F': ' '{print $2}' | tail -n 1)

    echo "**************************************"
    echo "Transaction ID: $txid"
    echo "From Address: ${miner_address}"
    echo "To Address: ${trader_address}"
    echo "Amount: $amount"
    echo "Fee: $(printf "%.8f" ${fees_paid})"
    echo "Block Height: $blockheight"
    echo "Miner Balance: $(bitcoin-cli -rpcwallet="Miner" getbalance)"
    echo "Trader Balance: $(bitcoin-cli -rpcwallet="Trader" getbalance)"
    echo "**************************************"
}



create_wallets
generate_miner_address_and_mine_blocks
generate_trader_address
send_amount
get_mempool
confirm_transaction
print_info



