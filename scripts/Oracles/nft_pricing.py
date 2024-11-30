import requests
from web3 import Web3
from web3.middleware import geth_poa_middleware
import json

# Configuration
API_KEY = "YOUR_OPENSEA_API_KEY"
INFURA_URL =  "https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID"
LOCAL_NODE_URL = "http://127.0.0.1:8545"
PRIVATE_KEY = "YOUR_PRIVATE_KEY" # <-- private key from local node
CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS" # <--- address of NftValues
ACCOUNT_ADDRESS = Web3(Web3.HTTPProvider(LOCAL_NODE_URL)).eth.account.from_key(PRIVATE_KEY).address


CONTRACT_ABI = []

# Connect to the local node
web3 = Web3(Web3.HTTPProvider(LOCAL_NODE_URL))
web3.middleware_onion.inject(geth_poa_middleware, layer=0)  # For PoA networks like Hardhat

# Create contract instance
contract = web3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)

def fetch_nft_data(collection_addr, token_id):
    """Fetch NFT data from OpenSea API."""
    url = f"https://api.opensea.io/api/v2/chain/ethereum/contract/{collection_addr}/nfts/{token_id}"
    headers = {"X-API-KEY": OPENSEA_API_KEY}
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error fetching data from OpenSea: {response.status_code}, {response.text}")
        return None


def calculate_nft_price(data):
    """Calculate the price of the NFT based on external data."""
    floor_price = data.get("collection", {}).get("stats", {}).get("floor_price", 0)
    last_sale_price = (
        int(data.get("last_sale", {}).get("total_price", 0)) / 10**18 if data.get("last_sale") else None
    )
    rarity_multiplier = 1.2  # Example multiplier for rare traits

    # Base price: weighted average of floor price and last sale price
    if last_sale_price:
        base_price = (floor_price * 0.7) + (last_sale_price * 0.3)
    else:
        base_price = floor_price

    # Apply rarity multiplier
    adjusted_price = base_price * rarity_multiplier
    return adjusted_price


def send_price_to_contract(collection_addr, token_id, price):
    """Send the calculated price back to the smart contract."""
    nonce = web3.eth.get_transaction_count(ACCOUNT_ADDRESS)
    tx = contract.functions.updateNftPrice(collection_addr, token_id, int(price * 10**18)).build_transaction({
        "chainId": 1337,  # Hardhat's local chain ID
        "gas": 300000,
        "gasPrice": 0,  # No gas fees for local testing
        "nonce": nonce,
    })

    signed_tx = web3.eth.account.sign_transaction(tx, PRIVATE_KEY)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    return web3.to_hex(tx_hash)


def listen_to_events():
    """Listen to the DataRequest event and process it."""
    print("Listening for events...")
    event_filter = contract.events.DataRequest.create_filter(fromBlock="latest")

    while True:
        for event in event_filter.get_new_entries():
            collection_addr = event.args["collectionAddr"]
            token_id = event.args["tokenId"]

            print(f"Received data request for Collection: {collection_addr}, Token ID: {token_id}")

            # Fetch data and calculate price
            nft_data = fetch_nft_data(collection_addr, token_id)
            if nft_data:
                price = calculate_nft_price(nft_data)
                print(f"Calculated Price: {price} ETH")

                # Send the price back to the contract
                tx_hash = send_price_to_contract(collection_addr, token_id, price)
                print(f"Transaction Hash: {tx_hash}")


if __name__ == "__main__":
    listen_to_events()