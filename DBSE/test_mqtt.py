import json, ssl, time, os
from random import randint
from requests import post, get
from dotenv import load_dotenv
import paho.mqtt.client as mqtt

load_dotenv()
username = os.getenv("usernameEntrade")
password = os.getenv("password")

print(f"[1] Đang authenticate với username: {username}...")
url = "https://api.dnse.com.vn/user-service/api/auth"
r = post(url, json={"username": username, "password": password})
print(f"    Status: {r.status_code}")

if r.status_code != 200:
    print(f"    Lỗi: {r.text[:300]}")
    exit(1)

token = r.json().get("token")
print(f"    Token (30 chars đầu): {token[:30]}...")

print("[2] Lấy investor info...")
r2 = get("https://api.dnse.com.vn/user-service/api/me",
         headers={"authorization": f"Bearer {token}"})
print(f"    Status: {r2.status_code}")

if r2.status_code != 200:
    print(f"    Lỗi: {r2.text[:300]}")
    exit(1)

info = r2.json()
investor_id = str(info.get("investorId", ""))
display_name = info.get("displayName", info.get("name", "N/A"))
print(f"    InvestorID: {investor_id}")
print(f"    Tên: {display_name}")

print("\n[3] Kết nối MQTT Broker...")
BROKER_HOST = "datafeed-lts-krx.dnse.com.vn"
BROKER_PORT = 443
client_id = f"dnse-price-json-mqtt-ws-sub-{randint(1000, 9999)}"
TOPIC = "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/41I1F7000"

messages_received = []

def on_connect(client, userdata, flags, rc, properties):
    if rc == 0 and client.is_connected():
        print("    ✅ Kết nối MQTT thành công!")
        client.subscribe(TOPIC, qos=1)
        print(f"    📡 Đã subscribe topic: {TOPIC}")
    else:
        print(f"    ❌ Kết nối thất bại, rc={rc}")

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        symbol = payload.get("symbol", "?")
        price  = payload.get("matchPrice", "?")
        qty    = payload.get("matchQtty", "?")
        side   = payload.get("side", "?")
        ts     = payload.get("sendingTime", "?")
        print(f"    📊 {symbol}: Giá={price} | KL={qty} | Side={side} | Time={ts}")
        messages_received.append(payload)
    except Exception as e:
        print(f"    ⚠️ Lỗi parse message: {e}")

client = mqtt.Client(
    mqtt.CallbackAPIVersion.VERSION2,
    client_id,
    protocol=mqtt.MQTTv5,
    transport="websockets"
)
client.username_pw_set(investor_id, token)
client.tls_set(cert_reqs=ssl.CERT_NONE)
client.tls_insecure_set(True)
client.ws_set_options(path="/wss")
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER_HOST, BROKER_PORT, keepalive=60)
client.loop_start()

print("    ⏳ Chờ 20 giây để nhận dữ liệu...")
time.sleep(20)

print(f"\n[4] Kết quả: Nhận được {len(messages_received)} messages")
client.disconnect()
client.loop_stop()
print("    Đã ngắt kết nối.")
