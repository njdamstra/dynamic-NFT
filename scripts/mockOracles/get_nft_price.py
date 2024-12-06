import json
import sys
from statistics import mean



# main function being called
def getNftPrice(collection, token_id, iteration):
    # print(f"Received: collection={collection}, token_id={token_id}, iteration={iteration}")
    general_data = getGeneralJsonFile(collection, token_id, iteration)
    sales_data = getSalesJsonFile(collection, token_id, iteration)
    # Prerequisite and security checks
    if not satisfy_prerequisites(general_data, collection, token_id):
        return 0

    if not security_checks(general_data):
        return 0

    # Extract relevant pricing data
    floor_price = getFloorPrice(general_data)
    avg_sales_price = getNftSalesPrice(sales_data)

    # Combine prices to determine fair price
    prices = [price for price in [floor_price, floor_price, avg_sales_price] if price > 0]
    
    if not prices:
        return 0  # No valid price data

    # Calculate the final price using average
    fair_price = mean(prices)

    return fair_price


### helper functions

def satisfy_prerequisites(data, collection, token_id):
    # data["name"] == "{collection} #{token_id}"
    try:
        return (
            data["chain"] == "ethereum"
            and data["contract"]["type"] == "ERC721"
            and not data["collection"]["is_nsfw"]
        )
    except KeyError as e:
        print(f"Missing key in data: {e}")
        return False
    



def security_checks(data):
    return True


def getGeneralJsonFile(collection, token_id, iteration):
    file_path = f"scripts/mockOracles/data/{collection}_{token_id}_general_{iteration}.json"
    try:
        with open(file_path, "r") as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return {}
    except json.JSONDecodeError:
        print(f"Invalid JSON in file: {file_path}")
        return {}

def getSalesJsonFile(collection, token_id, iteration):
    """Load the sales data JSON file."""
    file_path = f"scripts/mockOracles/data/{collection}_{token_id}_sales_{iteration}.json"
    try:
        with open(file_path, "r") as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return {}
    except json.JSONDecodeError:
        print(f"Invalid JSON in file: {file_path}")
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
    """Calculate the average sales price from the transfer history, excluding outliers."""
    transfers = data.get("transfers", [])
    
    # Extract ETH prices from the transfers
    eth_prices = [
        transfer["sale_details"]["unit_price"]
        for transfer in transfers
        if transfer["event_type"] == "sale"
        and not transfer["sale_details"]["is_bundle_sale"]
        and transfer["sale_details"]["payment_token"]["symbol"] == "ETH"
    ]
    
    if not eth_prices:
        return 0  # No valid prices found
    
    # Calculate the interquartile range (IQR)
    eth_prices.sort()
    q1 = eth_prices[len(eth_prices) // 4]  # First quartile
    q3 = eth_prices[3 * len(eth_prices) // 4]  # Third quartile
    iqr = q3 - q1

    # Define acceptable range
    lower_bound = q1 - 1.5 * iqr
    upper_bound = q3 + 1.5 * iqr

    # Filter out outliers
    filtered_prices = [price for price in eth_prices if lower_bound <= price <= upper_bound]

    # Return the mean of the filtered prices
    return mean(filtered_prices) if filtered_prices else 0


def getRarity(data):
    rank = data.rarity.rank
    score = data.rarity.score
    unique_attributes = data.rarity.unique_attributes
    return

def main():
    if len(sys.argv) != 4:
        print("Usage: python get_nft_price.py <collection_address> <token_id> <iteration>")
        sys.exit(1)

    collection = sys.argv[1]
    token_id = sys.argv[2]
    iteration = sys.argv[3]
    # print(f"Received: collection={collection}, token_id={token_id}, iteration={iteration}")
    price = getNftPrice(collection, token_id, iteration)
    print(price)

if __name__ == "__main__":
    main()
        
            


