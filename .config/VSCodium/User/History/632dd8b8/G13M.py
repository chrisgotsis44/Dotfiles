#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
import sys

# Map WMO weather codes from wttr.in to Emojis
WEATHER_CODES = {
    '113': '☀️', '116': '⛅', '119': '☁️', '122': '☁️', '143': '🌫',
    '176': '🌦', '179': '🌧', '182': '🌧', '185': '🌧', '200': '⛈',
    '227': '🌨', '230': '❄️', '248': '🌫', '260': '🌫', '263': '🌦',
    '266': '🌦', '281': '🌧', '284': '🌧', '293': '🌧', '296': '🌧',
    '299': '🌧', '302': '🌧', '305': '🌧', '308': '🌧', '311': '🌧',
    '314': '🌧', '317': '🌧', '320': '🌨', '323': '🌨', '326': '🌨',
    '329': '❄️', '332': '❄️', '335': '❄️', '338': '❄️', '350': '🌧',
    '353': '🌦', '356': '🌧', '359': '🌧', '362': '🌧', '365': '🌧',
    '368': '🌨', '371': '❄️', '374': '🌧', '377': '🌧', '386': '⛈',
    '389': '🌩', '392': '⛈', '395': '❄️'
}

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"text": "Error", "tooltip": "No location provided"}))
        sys.exit(1)

    location = sys.argv[1]
    # format=j1 returns the massive, highly detailed JSON data from wttr.in
    url = f"https://wttr.in/{location}?format=j1"

    try:
        # We spoof a curl User-Agent because wttr.in responds well to it
        req = urllib.request.Request(url, headers={'User-Agent': 'curl/7.68.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))

        # Extract current conditions
        current = data['current_condition'][0]
        weather_code = current['weatherCode']
        icon = WEATHER_CODES.get(weather_code, '✨')
        temp = current['temp_C']
        feels_like = current['FeelsLikeC']
        desc = current['weatherDesc'][0]['value']
        wind = current['windspeedKmph']
        humidity = current['humidity']

        # Format the text shown directly on the Waybar
        text = f"{icon} {temp}°C"

        # Build a beautiful, multi-line tooltip using Pango markup
        area = data['nearest_area'][0]['areaName'][0]['value']
        country = data['nearest_area'][0]['country'][0]['value']
        
        tooltip = f"<b>{area}, {country}</b>\n"
        tooltip += f"{desc}\n"
        tooltip += f"🌡️ Feels like: {feels_like}°C\n"
        tooltip += f"💨 Wind: {wind} km/h\n"
        tooltip += f"💧 Humidity: {humidity}%\n\n"
        tooltip += "<b>📅 3-Day Forecast:</b>\n"

        # Loop through the next 3 days of forecast data
        for day in data['weather']:
            date = day['date']
            max_c = day['maxtempC']
            min_c = day['mintempC']
            day_desc = day['hourly'][4]['weatherDesc'][0]['value'] # Grab noon description
            tooltip += f"{date}: ⬇️ {min_c}°C  ⬆️ {max_c}°C ({day_desc})\n"

        # Output the JSON expected by Waybar
        print(json.dumps({"text": text, "tooltip": tooltip.strip()}))

    except Exception as e:
        # Fallback if there is no internet or the API is down
        print(json.dumps({"text": "⚠️ Offline", "tooltip": f"Weather unavailable\n{str(e)}"}))

if __name__ == "__main__":
    main()