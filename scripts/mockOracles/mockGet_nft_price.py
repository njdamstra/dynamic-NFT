import json
import sys
from statistics import mean
from datetime import datetime, timezone
import requests


# main function being called
## collection = "gNft", "bNft" # token_id = 0, 1, 2, 3, 4 ... # iteration = 1,2,3,4,5 ...
def getNftPrice(collection_name, token_id, iteration):
    # print(f"Received: collection={collection}, token_id={token_id}, iteration={iteration}")
    collection_data = getGeneralJsonFile(collection_name, token_id, iteration)
    sales_data = getSalesJsonFile(collection_name, token_id)
    # Prerequisite and security checks
    if not canAcceptNFT(sales_data, collection_data):
        return 0

    floor_price = getFloorPrice(collection_data)

    if onlyUseFloorPrice(sales_data, collection_data):
        return floor_price

    # Extract relevant pricing data
    
    avg_sales_price = getNftSalesPrice(sales_data)

    # Combine prices to determine fair price
    prices = [price for price in [floor_price, floor_price, avg_sales_price] if price > 0]
    
    if not prices:
        return 0  # No valid price data

    # Calculate the final price using average
    fair_price = mean(prices)

    return fair_price


### helper functions

def canAcceptNFT(sales_data, collection_data):
    """Determine if the NFT is acceptable."""
    try:
        if not collection_data["chain"] == "ethereum" or not collection_data["contract"]["type"] == "ERC721":
            return False

        # Check if the collection is verified on at least one legitimate marketplace
        marketplaces = collection_data.get("collection", {}).get("marketplace_pages", [])
        verified_marketplaces = [
            market
            for market in marketplaces
            if market.get("marketplace_name") in ["OpenSea", "Blur", "LooksRare"] and market.get("verified", True)
        ]
        if not verified_marketplaces:
            return False  # Require at least one verified marketplace

        # Check that there are distinct owners
        distinct_owners = collection_data.get("collection", {}).get("distinct_owner_count", 0)
        if distinct_owners < 10:  # Require at least 10 unique owners
            return False

        # Check for NFT-specific criteria, e.g., not NSFW
        if collection_data.get("collection", {}).get("is_nsfw", False):
            return False

        return True
    except KeyError as e:
        print(f"Missing key in data: {e}")
        return False

def onlyUseFloorPrice(sales_data, collection_data):
    """Determine if the floor price should be used for the NFT valuation."""
    rarity = collection_data.get("rarity", {})
    rank = rarity.get("rank", None)
    score = rarity.get("score", None)

    num_owners = collection_data.get("collection", {}).get("distinct_owner_count", 0)
    total_quantity = collection_data.get("collection", {}).get("total_quantity", 0)
    sales_count = getNumberOfSales(sales_data)

    # High rank threshold is distinct_nft_count / 2
    high_rank_threshold = collection_data.get("collection", {}).get("distinct_nft_count", 0) / 2

    # Criteria for using the floor price:
    # 1. Very high rarity rank
    if rank and rank > high_rank_threshold:
        return True
    # 2. Low rarity score
    if score and score < 1.0:
        return True
    # 3. Low number of owners compared to total NFTs
    if total_quantity > 0 and (num_owners / total_quantity) < 0.2:  # Less than 20% unique ownership
        return True
    # 4. Few sales or unreliable sales history
    if sales_count < 3:
        return True

    # Otherwise, don't use the floor price
    return False


def getGeneralJsonFile(collection, token_id, iteration):
    file_path = f"scripts/mockOracles/data/{collection}/{collection}_general_{iteration}.json"
    try:
        with open(file_path, "r") as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return {}
    except json.JSONDecodeError:
        print(f"Invalid JSON in file: {file_path}")
        return {}

def getSalesJsonFile(collection, token_id):
    """Load the sales data JSON file."""
    file_path = f"scripts/mockOracles/data/{collection}/{collection}_{token_id}_sales.json"
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

def getNumberOfSales(data):
    """Calculate the number of sales for the NFT from the transfer history."""
    transfers = data.get("transfers", [])
    
    # Filter for sales events only
    sales_events = [
        transfer for transfer in transfers
        if transfer["event_type"] == "sale"
        and not transfer["sale_details"]["is_bundle_sale"]
        and transfer["sale_details"]["payment_token"]["symbol"] == "ETH"
    ]
    
    # Return the count of sales events
    return len(sales_events)

def getNftSalesPrice(data):
    """Calculate the average sales price in WEI from the transfer history, accounting for price fluctuations."""
    transfers = data.get("transfers", [])
    
    # Extract USD prices from the transfers
    usd_sales = [
        (transfer["sale_details"]["unit_price_usd_cents"] / 100, transfer["timestamp"])
        for transfer in transfers
        if transfer["event_type"] == "sale"
        and not transfer["sale_details"]["is_bundle_sale"]
        and "unit_price_usd_cents" in transfer["sale_details"]  # Ensure field exists
    ]
    
    if not usd_sales:
        return 0  # No valid prices found
    
    # Calculate the interquartile range (IQR)
    usd_prices = [sale[0] for sale in usd_sales]
    usd_prices.sort()
    q1 = usd_prices[len(usd_prices) // 4]  # First quartile
    q3 = usd_prices[3 * len(usd_prices) // 4]  # Third quartile
    iqr = q3 - q1

    # Define acceptable range
    lower_bound = q1 - 1.5 * iqr
    upper_bound = q3 + 1.5 * iqr

    # Filter out outliers
    filtered_sales = [(price, timestamp) for price, timestamp in usd_sales if lower_bound <= price <= upper_bound]

    if not filtered_sales:
        return 0  # No valid prices after filtering

    # Calculate time weights
    now = datetime.now(timezone.utc)
    weighted_prices = []
    weights = []
    
    for price, timestamp in filtered_sales:
        # Parse the timestamp into a datetime object
        sale_time = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        time_diff = (now - sale_time).total_seconds() / (60 * 60 * 24)  # Difference in days

        # Assign a weight inversely proportional to the age of the sale
        weight = 1 / (1 + time_diff)  # More recent sales have higher weights
        weighted_prices.append(price * weight)
        weights.append(weight)

    # Compute the time-weighted average price in USD
    time_weighted_avg_usd = sum(weighted_prices) / sum(weights) if weights else 0

    # Convert the USD price to WEI using the current ETH price
    current_eth_price = get_current_eth_price()
    if current_eth_price is None:
        print("Failed to fetch current ETH price. Returning 0.")
        return 0

    # Convert back to WEI (1 ETH = 10^18 WEI)
    time_weighted_avg_wei = (time_weighted_avg_usd / current_eth_price) * (10**18)
    time_weighted_avg_wei = int(time_weighted_avg_wei)  # Convert to integer for WEI

    return time_weighted_avg_wei

def get_current_eth_price():
    """Fetch the current ETH price in USD using the CoinGecko API."""
    try:
        url = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
        headers = {
            "accept": "application/json",
            "x-cg-demo-api-key": "CG-97iQsZ8UbpDEiTNYWbHPcNzf"
        }
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            return data["ethereum"]["usd"]
        else:
            print(f"Failed to fetch current ETH price: {response.status_code}")
            return None
    except Exception as e:
        print(f"Error fetching current ETH price: {e}")
        return None

def get_eth_price_at_timestamp(timestamp):
    """
    Fetch the historical price of ETH in USD at a given timestamp.
    :param timestamp: Unix timestamp of the sale (in seconds).
    :return: Price of ETH in USD at that time, or None if not found.
    """
    try:
        # Convert ISO 8601 timestamp to datetime object
        if isinstance(timestamp, str):
            sale_time = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ")
        else:
            raise ValueError(f"Invalid timestamp format: {timestamp}")

        # Convert to Unix timestamp in seconds
        unix_timestamp = int(sale_time.replace(tzinfo=timezone.utc).timestamp())

        # Convert timestamp to date string (CoinGecko format: 'dd-mm-yyyy')
        date_str = sale_time.strftime('%d-%m-%Y')
        # Query CoinGecko API for historical price
        url = f"https://api.coingecko.com/api/v3/coins/ethereum/history?date={date_str}"
        headers = {
            "accept": "application/json",
            "x-cg-demo-api-key": "CG-97iQsZ8UbpDEiTNYWbHPcNzf"
        }
        response = requests.get(url, headers=headers)

        # Check if response is valid
        if response.status_code == 200:
            data = response.json()
            return data["market_data"]["current_price"]["usd"]
        else:
            print(f"Failed to fetch price data: {response.status_code} for {date_str}")
            return None
    except ValueError as ve:
        print(f"Invalid timestamp value: {ve}")
        return None
    except Exception as e:
        print(f"Error fetching ETH price: {e}")
        return None

def main():
    if len(sys.argv) != 4:
        print("Usage: python mockGet_nft_price.py <collection_address> <token_id> <iteration>")
        sys.exit(1)

    collection = sys.argv[1]
    token_id = sys.argv[2]
    iteration = sys.argv[3]
    # print(f"Received: collection={collection}, token_id={token_id}, iteration={iteration}")
    price = getNftPrice(collection, token_id, iteration)
    print(price)

if __name__ == "__main__":
    main()
        
            


