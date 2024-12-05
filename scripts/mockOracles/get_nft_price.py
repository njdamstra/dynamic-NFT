import json
import sys
from statistics import mean

def main():
    if len(sys.argv) != 4:
        print("Usage: python get_nft_price.py <collection_address> <token_id>")
        sys.exit(1)

    collection = sys.argv[1]
    token_id = sys.argv[2]
    iteration = sys.argv[3]
    price = getNftPrice(collection, token_id, iteration)
    print(price)

if __name__ == "__main__":
    main()

# main function being called
def getNftPrice(collection, token_id, iteration):
    return 10
    # general_data = getGeneralJsonFile(collection, token_id, iteration)
    # sales_data = getSalesJsonFile(collection, token_id, iteration)
    # # Prerequisite and security checks
    # if not satisfy_prerequisites(general_data, collection, token_id):
    #     return 0

    # if not security_checks(general_data):
    #     return 0

    # # Extract relevant pricing data
    # floor_price = getFloorPrice(general_data)
    # avg_sales_price = getNftSalesPrice(sales_data)

    # # Combine prices to determine fair price
    # prices = [price for price in [floor_price, last_sale_price, avg_sales_price] if price > 0]
    
    # if not prices:
    #     return 0  # No valid price data

    # # Calculate the final price using average
    # fair_price = mean(prices)

    # return fair_price


### helper functions

def satisfy_prerequisites(data, collection, token_id):
    return (
        data["contract_address"] == collection
        and data["token_id"] == str(token_id)
        and data["chain"] == "ethereum"
        and data["contract"]["type"] == "ERC721"
        and not data["collection"]["is_nsfw"]
    )
    



def security_checks(data):


def getGeneralJsonFile(collection, token_id, iteration):
    try:
        with open(f"data/{collection}_{token_id}_general_{iteration}.json", "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    return

def getSalesJsonFile(collection, token_id, iteration):
    """Load the sales data JSON file."""
    try:
        with open(f"data/{collection}_{token_id}_sales_{iteration}.json", "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def getFloorPrice(data):
    """Calculate the average floor price across marketplaces."""
    floor_prices = data["collection"]["floor_prices"]
    eth_prices = [
        market["value"]
        for market in floor_prices
        if market["payment_token"]["symbol"] == "ETH"
    ]
    return mean(eth_prices) if eth_prices else 0

def getNftSalesPrice(data):
    """Calculate the average sales price from the transfer history."""
    transfers = data.get("transfers", [])
    eth_prices = [
        transfer["sale_details"]["unit_price"]
        for transfer in transfers
        if transfer["event_type"] == "sale"
        and not transfer["sale_details"]["is_bundle_sale"]
        and transfer["sale_details"]["payment_token"]["symbol"] == "ETH"
    ]
    return mean(eth_prices) if eth_prices else 0

def getRarity(data):
    rank = data.rarity.rank
    score = data.rarity.score
    unique_attributes = data.rarity.unique_attributes

        
            


