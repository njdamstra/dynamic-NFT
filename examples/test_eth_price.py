
from datetime import datetime, timezone
import requests

## CG-97iQsZ8UbpDEiTNYWbHPcNzf

def get_eth_price_at_timestamp(timestamp):
    """
    Fetch the historical price of ETH in USD at a given timestamp.
    """
    try:
        # Convert timestamp to ISO 8601 format (CoinGecko uses UTC dates)
        date_str = datetime.fromtimestamp(timestamp, tz=timezone.utc).strftime('%d-%m-%Y')

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
            if "market_data" in data and "current_price" in data["market_data"]:
                return data["market_data"]["current_price"]["usd"]
            else:
                print(f"Missing market data for date: {date_str}")
                return None
        else:
            print(f"Failed to fetch price data: {response.status_code} for {date_str}")
            return None
    except Exception as e:
        print(f"Error fetching ETH price: {e}")
        return None

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

# Test the function
if __name__ == "__main__":
    test_timestamp = 1714805000  # Replace with a valid Unix timestamp
    eth_price = get_eth_price_at_timestamp(test_timestamp)
    eth_usd_now = get_current_eth_price()
    print(f"ETH price at {test_timestamp}: {eth_price}")
    print(f"current ETH price compared to USD: {eth_usd_now}")

