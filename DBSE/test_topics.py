"""
Test nhiều topic DNSE MQTT để xem topic nào đang active
"""
import json, ssl, time, os
from random import randint
from requests import post, get
from dotenv import load_dotenv
import paho.mqtt.client as mqtt

load_dotenv()
username = os.getenv("usernameEntrade")
password = os.getenv("password")

# Authenticate
print("[1] Authenticating...")
r = post("https://api.dnse.com.vn/user-service/api/auth",
         json={"username": username, "password": password})
token = r.json().get("token")
r2 = get("https://api.dnse.com.vn/user-service/api/me",
          headers={"authorization": f"Bearer {token}"})
info = r2.json()
investor_id = str(info.get("investorId", ""))
print(f"    InvestorID: {investor_id}")

# Các topic để test (cổ phiếu thường HOSE + HNX + phái sinh)
TOPICS = [
    # Tick data - cổ phiếu thường
    "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/VIC",
    "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/VNM",
    "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/HPG",
    "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/VHM",
    "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/MWG",
    # Độ sâu thị trường (market depth)
    "plaintext/quotes/krx/mdds/depth/v1/symbol/VIC",
    "plaintext/quotes/krx/mdds/depth/v1/symbol/VNM",
    # Index
    "plaintext/quotes/krx/mdds/index/v1/symbol/VNINDEX",
    "plaintext/quotes/krx/mdds/index/v1/symbol/VN30",
    # Wildcard
    "plaintext/quotes/krx/mdds/tick/v1/roundlot/symbol/#",
]

messages_by_topic = {}
connect_success = False

def on_connect(client, userdata, flags, rc, properties):
    global connect_success
    if rc == 0 and client.is_connected():
        connect_success = True
        print(f"\n[2] ✅ Kết nối MQTT thành công!")
        for topic in TOPICS:
            client.subscribe(topic, qos=0)
            print(f"    📡 Subscribe: {topic}")
    else:
        print(f"    ❌ Kết nối thất bại, rc={rc}")

def on_message(client, userdata, msg):
    topic = msg.topic
    if topic not in messages_by_topic:
        messages_by_topic[topic] = 0
        print(f"\n    🎯 NHẬN DATA TỪ TOPIC: {topic}")
        try:
            payload = json.loads(msg.payload.decode())
            print(f"       Payload keys: {list(payload.keys())}")
            print(f"       Sample: {str(payload)[:200]}")
        except:
            print(f"       Raw: {msg.payload[:100]}")
    messages_by_topic[topic] += 1

def on_log(client, userdata, level, buf):
    if "CONNECT" in buf or "DISCONNECT" in buf or "ERROR" in buf or "FAIL" in buf:
        print(f"    [LOG] {buf}")

client = mqtt.Client(
    mqtt.CallbackAPIVersion.VERSION2,
    f"test-{randint(1000, 9999)}",
    protocol=mqtt.MQTTv5,
    transport="websockets"
)
client.username_pw_set(investor_id, token)
client.tls_set(cert_reqs=ssl.CERT_NONE)
client.tls_insecure_set(True)
client.ws_set_options(path="/wss")
client.on_connect = on_connect
client.on_message = on_message
client.on_log = on_log

print("\n[2] Đang kết nối MQTT...")
client.connect("datafeed-lts-krx.dnse.com.vn", 443, keepalive=60)
client.loop_start()

wait = 30
print(f"\n[3] Chờ {wait} giây để nhận dữ liệu...")
for i in range(wait):
    time.sleep(1)
    if (i+1) % 5 == 0:
        print(f"    ... {i+1}s / {wait}s | Messages nhận: {sum(messages_by_topic.values())}")

print(f"\n[4] KẾT QUẢ:")
print(f"    Kết nối thành công: {connect_success}")
print(f"    Tổng messages: {sum(messages_by_topic.values())}")
if messages_by_topic:
    print(f"    Topics có data:")
    for t, count in messages_by_topic.items():
        print(f"      - {t}: {count} messages")
else:
    print("    ⚠️ Không nhận được message nào -> Ngoài giờ giao dịch hoặc topic sai")
    print("    💡 Giờ giao dịch: 9:00 - 15:00 ngày làm việc")

client.disconnect()
client.loop_stop()
