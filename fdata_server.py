#!/usr/bin/env python3
"""
FData Server v4.0 - DNSE WebSocket SDK + REST API (no AmiBroker .dat)
  - Historical OHLC từ DNSE REST API (1m → 1D)
  - Live bar realtime (update từng tick qua WS)
  - Bid/Ask orderbook 3 mức giá
  - Quotes cho watchlist tùy chỉnh
Chay: python fdata_server.py
API: http://localhost:8765
"""

import sys, os, json, threading, asyncio, logging, time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, urlencode
from urllib import request as urllib_request
from datetime import datetime, timezone, timedelta
from collections import defaultdict
import base64, hashlib, hmac as hmac_lib, uuid

# ─── Load .env ────────────────────────────────────────────────────────────────
try:
    from dotenv import load_dotenv
    _env_path = os.path.join(os.path.dirname(__file__),
                             "dnse_stock_app", "dnse", ".env")
    load_dotenv(_env_path)
except ImportError:
    pass

# ─── SDK path ─────────────────────────────────────────────────────────────────
SDK_WS_PATH   = os.path.join(os.path.dirname(__file__),
    "dnse_stock_app", "openapi-sdk", "python", "websocket-marketdata")
SDK_REST_PATH = os.path.join(os.path.dirname(__file__),
    "dnse_stock_app", "openapi-sdk", "python")
for _p in (SDK_WS_PATH, SDK_REST_PATH):
    if _p not in sys.path:
        sys.path.insert(0, _p)

# ─── Config ───────────────────────────────────────────────────────────────────
PORT            = 8765
HOST            = "0.0.0.0"
DNSE_API_KEY    = os.getenv("DNSE_API_KEY", "")
DNSE_API_SECRET = os.getenv("DNSE_API_SECRET", "")
DNSE_WS_URL     = "wss://ws-openapi.dnse.com.vn"
DNSE_REST_URL   = "https://openapi.dnse.com.vn"

# Watchlist mặc định — thêm mã vào EXTRA_SYMBOLS trong .env (cách nhau bởi dấu phẩy)
_VN30 = [
    "ACB","BCM","BID","BVH","CTG","FPT","GAS","GVR","HDB","HPG",
    "MBB","MSN","MWG","PLX","POW","SAB","SHB","SSB","SSI","STB",
    "TCB","TPB","VCB","VHM","VIB","VIC","VND","VNM","VPB","VRE",
]
_extra = [s.strip().upper() for s in os.getenv("EXTRA_SYMBOLS", "").split(",") if s.strip()]
WATCHLIST = list(dict.fromkeys(_VN30 + _extra))  # deduplicate, giữ thứ tự

TF_TO_DNSE = {
    "1m": "1", "3m": "3", "5m": "5", "15m": "15",
    "30m": "30", "1H": "1H", "1D": "1D", "EOD": "1D",
}
MAX_RT_BARS  = 600
MAX_RT_TICKS = 500

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s][%(levelname)s] %(message)s",
    datefmt="%H:%M:%S"
)
log = logging.getLogger("fdata")

# ═══════════════════════════════════════════════════════════════════════════════
# DNSE REST Client (dùng SDK DNSEClient)
# ═══════════════════════════════════════════════════════════════════════════════
class DNSERestClient:
    """Wrapper quanh DNSEClient SDK để tiện sử dụng trong fdata_server."""
    def __init__(self, api_key, api_secret):
        from dnse import DNSEClient
        self._client = DNSEClient(
            api_key=api_key,
            api_secret=api_secret,
            base_url=DNSE_REST_URL,
        )

    def get_ohlc(self, symbol, resolution="1", from_ts=None, to_ts=None, bar_type="STOCK"):
        if not from_ts:
            now_ict = datetime.now(timezone(timedelta(hours=7)))
            sod     = now_ict.replace(hour=0, minute=0, second=0, microsecond=0)
            from_ts = int(sod.astimezone(timezone.utc).timestamp())
        if not to_ts:
            to_ts = int(time.time())
        status, body = self._client.get_ohlc(
            bar_type=bar_type,
            query={"symbol": symbol, "resolution": resolution, "from": from_ts, "to": to_ts},
        )
        if status != 200:
            log.warning(f"REST get_ohlc {symbol} r={resolution}: HTTP {status} {body[:200] if body else ''}")
            return None
        return json.loads(body) if isinstance(body, str) else body

    def parse_ohlc_to_candles(self, body, tf):
        if not body: return []
        candles = []

        # Format 1: columnar arrays {t:[...], o:[...], h:[...], l:[...], c:[...], v:[...]}
        if isinstance(body, dict) and "t" in body and isinstance(body.get("t"), list):
            t_arr = body["t"] or []
            o_arr = body.get("o") or []
            h_arr = body.get("h") or []
            l_arr = body.get("l") or []
            c_arr = body.get("c") or []
            v_arr = body.get("v") or []
            for i, ts in enumerate(t_arr):
                if not ts: continue
                dt       = datetime.fromtimestamp(ts, tz=timezone(timedelta(hours=7)))
                date_int = int(dt.strftime("%Y%m%d"))
                time_int = int(dt.strftime("%H%M%S"))
                candles.append({
                    "date": date_int, "time": time_int,
                    "open":   float(o_arr[i] or 0) if i < len(o_arr) else 0,
                    "high":   float(h_arr[i] or 0) if i < len(h_arr) else 0,
                    "low":    float(l_arr[i] or 0) if i < len(l_arr) else 0,
                    "close":  float(c_arr[i] or 0) if i < len(c_arr) else 0,
                    "volume": int(v_arr[i]   or 0) if i < len(v_arr) else 0,
                    "source": "rest",
                })
            return candles

        # Format 2: list of objects [{time:..., open:..., ...}]
        items = body if isinstance(body, list) else body.get("data", body.get("bars", []))
        for item in items:
            ts = int(item.get("time") or item.get("t") or 0)
            if not ts: continue
            dt       = datetime.fromtimestamp(ts, tz=timezone(timedelta(hours=7)))
            date_int = int(dt.strftime("%Y%m%d"))
            time_int = int(dt.strftime("%H%M%S"))
            candles.append({
                "date": date_int, "time": time_int,
                "open":   float(item.get("open")   or item.get("o") or 0),
                "high":   float(item.get("high")   or item.get("h") or 0),
                "low":    float(item.get("low")    or item.get("l") or 0),
                "close":  float(item.get("close")  or item.get("c") or 0),
                "volume": int(item.get("volume")   or item.get("v") or 0),
                "source": "rest",
            })
        return candles


_rest_client      = None
_rest_client_lock = threading.Lock()

def get_rest_client():
    global _rest_client
    if not DNSE_API_KEY: return None
    with _rest_client_lock:
        if _rest_client is None:
            _rest_client = DNSERestClient(DNSE_API_KEY, DNSE_API_SECRET)
    return _rest_client

# ═══════════════════════════════════════════════════════════════════════════════
# Realtime Cache (thread-safe)
# ═══════════════════════════════════════════════════════════════════════════════
_cache_lock   = threading.Lock()
_rt_quotes    = {}                  # symbol → quote dict
_rt_candles   = defaultdict(list)  # "VCB_1m" → list[candle]
_rt_orderbook = {}                  # symbol → {bid, ask, ts}
_rt_ticks     = defaultdict(list)  # symbol → list of recent ticks
_live_bar     = {}                  # symbol → current open bar (1m)
_rt_secdef    = {}                  # symbol → {reference, ceiling, floor}

_ws_connected        = False
_ws_subscribed_syms  = set()
_ws_subscribed_keys  = set()

# ═══════════════════════════════════════════════════════════════════════════════
# WebSocket event handlers
# ═══════════════════════════════════════════════════════════════════════════════
def on_secdef_update(secdef):
    """Security definition: giá tham chiếu, trần, sàn — push lúc 8h sáng."""
    try:
        sym = (secdef.symbol or "").upper()
        ref  = float(secdef.referencePrice or 0)
        ceil = float(secdef.ceilingPrice    or 0)
        flr  = float(secdef.floorPrice      or 0)
        if not sym or ref == 0: return
        with _cache_lock:
            _rt_secdef[sym] = {"reference": ref, "ceiling": ceil, "floor": flr}
            q = _rt_quotes.get(sym, {})
            q.setdefault("reference", ref)
            q.setdefault("ceiling",   ceil)
            q.setdefault("floor",     flr)
            q["symbol"] = sym
            _rt_quotes[sym] = q
    except Exception as e:
        log.error(f"on_secdef_update: {e}")

def on_ohlc_update(ohlc):
    """DNSE push OHLC bar (live update hoặc bar vừa đóng)."""
    try:
        sym = (ohlc.symbol or "").upper()
        res = str(ohlc.resolution or "1")
        tf  = {"1":"1m","3":"3m","5":"5m","15":"15m","30":"30m","1H":"1H","1D":"1D"}.get(res, res)
        key = f"{sym}_{tf}"
        ts  = int(ohlc.time or 0)
        if not ts: return
        dt       = datetime.fromtimestamp(ts, tz=timezone(timedelta(hours=7)))
        date_int = int(dt.strftime("%Y%m%d"))
        time_int = int(dt.strftime("%H%M%S"))
        candle   = {
            "date": date_int, "time": time_int,
            "open":  float(ohlc.open  or 0), "high": float(ohlc.high or 0),
            "low":   float(ohlc.low   or 0), "close": float(ohlc.close or 0),
            "volume": int(ohlc.volume or 0), "source": "ws",
        }
        with _cache_lock:
            bars = _rt_candles[key]
            if bars and bars[-1]["date"] == date_int and bars[-1]["time"] == time_int:
                bars[-1] = candle
            else:
                bars.append(candle)
            if len(bars) > MAX_RT_BARS:
                _rt_candles[key] = bars[-MAX_RT_BARS:]
    except Exception as e:
        log.error(f"on_ohlc_update: {e}")

def on_trade_update(trade):
    """DNSE push tick giao dịch — cập nhật giá + build live 1m bar."""
    try:
        sym   = (trade.symbol or "").upper()
        price = float(trade.price or 0)
        qty   = int(trade.quantity or 0)
        tvt   = int(trade.totalVolumeTraded or 0)
        hp    = float(trade.highestPrice or 0)
        lp    = float(trade.lowestPrice  or 0)
        op    = float(trade.openPrice    or 0)
        now   = datetime.now(tz=timezone(timedelta(hours=7)))
        ts    = int(now.strftime("%H%M%S"))
        di    = int(now.strftime("%Y%m%d"))

        with _cache_lock:
            # 1. Cập nhật quote realtime
            q = _rt_quotes.get(sym, {})
            sd = _rt_secdef.get(sym, {})
            q.update({
                "symbol": sym, "price": round(price, 2),
                "high": round(hp, 2), "low": round(lp, 2),
                "open": round(op, 2), "volume": tvt, "source": "ws",
            })
            # Điền ref/ceil/floor từ secdef nếu chưa có
            for k in ("reference", "ceiling", "floor"):
                if sd.get(k): q.setdefault(k, sd[k])
            ref = q.get("reference", 0)
            if ref > 0:
                q["change"]     = round(price - ref, 2)
                q["change_pct"] = round((price - ref) / ref * 100, 2)
            _rt_quotes[sym] = q

            # 2. Lưu tick
            ticks = _rt_ticks[sym]
            ticks.append({"time": ts, "price": price, "qty": qty})
            if len(ticks) > MAX_RT_TICKS:
                _rt_ticks[sym] = ticks[-MAX_RT_TICKS:]

            # 3. Build/update live 1m bar từ tick
            minute_key = now.strftime("%Y%m%d%H%M")
            lb = _live_bar.get(sym)
            if lb and lb.get("minute") == minute_key:
                lb["high"]   = max(lb["high"], price)
                lb["low"]    = min(lb["low"], price)
                lb["close"]  = price
                lb["volume"] += qty
            else:
                if lb:
                    old = {"date": lb["date"], "time": lb["time"],
                           "open": lb["open"], "high": lb["high"],
                           "low": lb["low"], "close": lb["close"],
                           "volume": lb["volume"], "source": "ws"}
                    bars = _rt_candles[f"{sym}_1m"]
                    if bars and bars[-1]["date"] == old["date"] and bars[-1]["time"] == old["time"]:
                        bars[-1] = old
                    else:
                        bars.append(old)
                    if len(bars) > MAX_RT_BARS:
                        _rt_candles[f"{sym}_1m"] = bars[-MAX_RT_BARS:]
                bar_time = int(now.replace(second=0, microsecond=0).strftime("%H%M%S"))
                _live_bar[sym] = {
                    "minute": minute_key,
                    "date": di, "time": bar_time,
                    "open": price, "high": price, "low": price,
                    "close": price, "volume": qty, "source": "live",
                }
    except Exception as e:
        log.error(f"on_trade_update: {e}")

def on_quote_update(quote):
    """DNSE push bid/ask orderbook."""
    try:
        sym = (quote.symbol or "").upper()
        def pl(lst): return [{"price": float(x.price or 0), "qty": int(x.quantity or 0)} for x in (lst or []) if x.price is not None]
        with _cache_lock:
            _rt_orderbook[sym] = {
                "symbol": sym,
                "bid": pl(quote.bid)[:3],
                "ask": pl(quote.offer)[:3],
                "totalBidQty": int(quote.totalBidQtty   or 0),
                "totalAskQty": int(quote.totalOfferQtty or 0),
                "updatedAt": int(time.time()),
            }
    except Exception as e:
        log.error(f"on_quote_update: {e}")

# ═══════════════════════════════════════════════════════════════════════════════
# REST pre-fetch
# ═══════════════════════════════════════════════════════════════════════════════
_INTRADAY_TFS  = {"1m", "3m", "5m", "15m", "30m", "1H"}
_prefetched_keys = set()   # "SYM_tf"
_prefetched_eod  = set()   # symbol đã fetch EOD chưa

def _prefetch_intraday(symbol, tf):
    rc = get_rest_client()
    if not rc: return
    sym    = symbol.upper()
    key_1m = f"{sym}_1m"
    key_tf = f"{sym}_{tf}"

    with _cache_lock:
        if key_tf in _prefetched_keys: return
        _prefetched_keys.add(key_tf)
        already_1m = key_1m in _prefetched_keys

    if not already_1m:
        log.info(f"[REST] Fetching {sym} 1m intraday...")
        body    = rc.get_ohlc(sym, resolution="1")
        bars_1m = rc.parse_ohlc_to_candles(body, "1m")
        with _cache_lock:
            _prefetched_keys.add(key_1m)
            if bars_1m:
                existing   = _rt_candles[key_1m]
                exist_keys = {(b["date"], b["time"]) for b in existing}
                new_bars   = [c for c in bars_1m if (c["date"], c["time"]) not in exist_keys]
                existing.extend(new_bars)
                existing.sort(key=lambda x: (x["date"], x["time"]))
                log.info(f"[REST] {sym} 1m: {len(bars_1m)} bars")
    else:
        with _cache_lock:
            bars_1m = list(_rt_candles.get(key_1m, []))

    if tf != "1m" and tf in _INTRADAY_TFS:
        with _cache_lock:
            bars_1m_cur = list(_rt_candles.get(key_1m, []))
        resampled = _resample_1m_to_tf(bars_1m_cur, tf)
        if resampled:
            with _cache_lock:
                existing   = _rt_candles[key_tf]
                exist_keys = {(b["date"], b["time"]) for b in existing}
                new_bars   = [c for c in resampled if (c["date"], c["time"]) not in exist_keys]
                existing.extend(new_bars)
                existing.sort(key=lambda x: (x["date"], x["time"]))

def _prefetch_eod(symbol, days=90):
    """Lấy historical OHLC ngày (1D) từ DNSE REST API."""
    rc = get_rest_client()
    if not rc: return
    sym = symbol.upper()
    key = f"{sym}_1D"

    with _cache_lock:
        if sym in _prefetched_eod: return
        _prefetched_eod.add(sym)

    now_ict = datetime.now(timezone(timedelta(hours=7)))
    from_dt = now_ict - timedelta(days=days)
    from_ts = int(from_dt.replace(hour=0, minute=0, second=0).astimezone(timezone.utc).timestamp())
    to_ts   = int(time.time())

    log.info(f"[REST-EOD] Fetching {sym} 1D ({days}d)...")
    body = rc.get_ohlc(sym, resolution="1D", from_ts=from_ts, to_ts=to_ts)
    bars = rc.parse_ohlc_to_candles(body, "1D")
    if not bars:
        log.warning(f"[REST-EOD] {sym}: không có data")
        return

    with _cache_lock:
        existing   = _rt_candles[key]
        exist_keys = {(b["date"], b["time"]) for b in existing}
        new_bars   = [c for c in bars if (c["date"], c["time"]) not in exist_keys]
        existing.extend(new_bars)
        existing.sort(key=lambda x: (x["date"], x["time"]))
    log.info(f"[REST-EOD] {sym}: {len(bars)} bars, +{len(new_bars)} mới")

    # Cập nhật quote từ nến cuối ngày nếu chưa có WS data
    if bars:
        last = bars[-1]
        with _cache_lock:
            q = _rt_quotes.get(sym, {})
            if not q.get("price"):
                ref = q.get("reference", 0) or last["close"]
                q.update({
                    "symbol": sym, "price": last["close"],
                    "open": last["open"], "high": last["high"],
                    "low": last["low"], "volume": last["volume"],
                    "change":     round(last["close"] - ref, 2) if ref else 0,
                    "change_pct": round((last["close"] - ref) / ref * 100, 2) if ref else 0,
                    "source": "rest_eod",
                })
                q.setdefault("reference", ref)
                q.setdefault("ceiling",   round(ref * 1.07, 2))
                q.setdefault("floor",     round(ref * 0.93, 2))
                _rt_quotes[sym] = q

def _resample_1m_to_tf(bars_1m, target_tf):
    tf_min = {"1m":1,"3m":3,"5m":5,"15m":15,"30m":30,"1H":60}.get(target_tf, 60)
    if tf_min <= 1: return bars_1m
    result, bucket, bucket_open_min = [], [], None
    for bar in bars_1m:
        t = bar["time"]
        hh, mm = t // 10000, (t % 10000) // 100
        bucket_min = ((hh * 60 + mm) // tf_min) * tf_min
        if bucket_open_min is None: bucket_open_min = bucket_min
        if bucket_min != bucket_open_min:
            if bucket: result.append(_merge_bucket(bucket))
            bucket = [bar]; bucket_open_min = bucket_min
        else:
            bucket.append(bar)
    if bucket: result.append(_merge_bucket(bucket))
    return result

def _merge_bucket(bars, source="rest_resample"):
    return {
        "date": bars[0]["date"], "time": bars[0]["time"],
        "open": bars[0]["open"], "high": max(b["high"] for b in bars),
        "low":  min(b["low"]  for b in bars),
        "close": bars[-1]["close"], "volume": sum(b["volume"] for b in bars),
        "source": source,
    }

def prefetch_async(symbol, tf):
    sym = symbol.upper()
    key = f"{sym}_{tf}"
    with _cache_lock:
        if key in _prefetched_keys: return
    threading.Thread(target=_prefetch_intraday, args=(sym, tf), daemon=True).start()

def prefetch_eod_async(symbol):
    sym = symbol.upper()
    with _cache_lock:
        if sym in _prefetched_eod: return
    threading.Thread(target=_prefetch_eod, args=(sym,), daemon=True).start()

# ═══════════════════════════════════════════════════════════════════════════════
# WebSocket Manager
# ═══════════════════════════════════════════════════════════════════════════════
_ws_loop   = None
_ws_client = None

async def _ws_main():
    global _ws_connected, _ws_client
    if not DNSE_API_KEY:
        log.warning("[WS] Không có DNSE_API_KEY → không có realtime")
        return
    try:
        from trading_websocket import TradingClient
    except ImportError as e:
        log.error(f"[WS] SDK import fail: {e}"); return

    log.info(f"[WS] Connecting to {DNSE_WS_URL} ...")
    _ws_client = TradingClient(
        api_key=DNSE_API_KEY, api_secret=DNSE_API_SECRET,
        base_url=DNSE_WS_URL, encoding="json",
        auto_reconnect=True, max_retries=30,
        heartbeat_interval=25.0,
    )
    try:
        await _ws_client.connect()
        _ws_connected = True
        log.info("[WS] Connected & authenticated!")
        _ws_client.on("trade",       on_trade_update)
        _ws_client.on("ohlc",        on_ohlc_update)
        _ws_client.on("quote",       on_quote_update)
        _ws_client.on("reconnected", lambda d: log.info(f"[WS] Reconnected"))
        # Subscribe security_definition để lấy ref/ceil/floor
        try:
            await _ws_client.subscribe_security_definition(WATCHLIST)
            log.info(f"[WS] Subscribed sec_def: {len(WATCHLIST)} symbols")
        except Exception as e:
            log.warning(f"[WS] sec_def subscribe skip: {e}")
        while True:
            await asyncio.sleep(60)
    except Exception as e:
        log.error(f"[WS] Fatal: {e}")
        _ws_connected = False

async def _do_subscribe(symbol, tfs):
    global _ws_client
    if not _ws_client or not _ws_connected: return
    sym = symbol.upper()
    try:
        if sym not in _ws_subscribed_syms:
            await _ws_client.subscribe_trades([sym])
            await _ws_client.subscribe_quotes([sym])
            _ws_subscribed_syms.add(sym)
            log.info(f"[WS] Subscribed trade+quote: {sym}")
        for tf in tfs:
            key    = f"{sym}_{tf}"
            dnse_r = TF_TO_DNSE.get(tf)
            if dnse_r and key not in _ws_subscribed_keys:
                await _ws_client.subscribe_ohlc([sym], resolution=dnse_r)
                _ws_subscribed_keys.add(key)
                log.info(f"[WS] Subscribed OHLC {sym} res={dnse_r}")
    except Exception as e:
        log.error(f"[WS] Subscribe {symbol}: {e}")

def subscribe_symbol(symbol, tfs=None):
    if tfs is None: tfs = ["1m", "15m", "1D"]
    global _ws_loop
    if _ws_loop and _ws_loop.is_running():
        asyncio.run_coroutine_threadsafe(_do_subscribe(symbol, tfs), _ws_loop)
    sym = symbol.upper()
    for tf in tfs:
        if tf in _INTRADAY_TFS:
            prefetch_async(sym, tf)

def start_ws_thread():
    global _ws_loop
    _ws_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(_ws_loop)
    _ws_loop.run_until_complete(_ws_main())

# ═══════════════════════════════════════════════════════════════════════════════
# API endpoint handlers
# ═══════════════════════════════════════════════════════════════════════════════
def api_symbols(params):
    """Trả về danh sách symbols từ WATCHLIST."""
    return {"symbols": WATCHLIST, "count": len(WATCHLIST)}

def api_quotes(params):
    limit  = int(params.get("limit", ["500"])[0])
    syms   = WATCHLIST[:limit]
    quotes = []
    for sym in syms:
        # Đảm bảo đang subscribe + prefetch EOD
        subscribe_symbol(sym, tfs=["1m", "15m", "1D"])
        prefetch_eod_async(sym)
        with _cache_lock:
            rt = dict(_rt_quotes.get(sym, {}))
        if rt:
            quotes.append(rt)
    return {"quotes": quotes, "count": len(quotes)}

def api_candles(symbol, params):
    tf    = params.get("timeframe", ["1D"])[0]
    limit = int(params.get("limit", ["300"])[0])
    sym   = symbol.upper()
    subscribe_symbol(sym, tfs=[tf, "1m"])

    # Đảm bảo có REST data
    if tf in ("EOD", "1D"):
        prefetch_eod_async(sym)
    else:
        prefetch_async(sym, tf)

    # Lấy từ cache
    key = f"{sym}_1D" if tf in ("EOD", "1D") else f"{sym}_{tf}"
    with _cache_lock:
        bars = list(_rt_candles.get(key, []))
        # Append live bar nếu tf=1m
        if tf == "1m":
            lb = _live_bar.get(sym)
            if lb:
                live = {"date": lb["date"], "time": lb["time"],
                        "open": lb["open"], "high": lb["high"],
                        "low": lb["low"], "close": lb["close"],
                        "volume": lb["volume"], "source": "live"}
                if bars and bars[-1]["date"] == live["date"] and bars[-1]["time"] == live["time"]:
                    bars[-1] = live
                else:
                    bars.append(live)

    candles = bars[-limit:] if len(bars) > limit else bars
    return {
        "symbol": sym, "timeframe": tf,
        "candles": candles, "count": len(candles),
        "has_realtime": bool(bars),
    }

def api_orderbook(symbol):
    sym = symbol.upper()
    subscribe_symbol(sym)
    with _cache_lock:
        ob = _rt_orderbook.get(sym)
    if ob:
        return ob
    return {"symbol": sym, "bid": [], "ask": [], "totalBidQty": 0, "totalAskQty": 0, "updatedAt": 0}

def api_ticks(symbol, params):
    sym   = symbol.upper()
    limit = int(params.get("limit", ["100"])[0])
    with _cache_lock:
        ticks = list(_rt_ticks.get(sym, []))[-limit:]
    return {"symbol": sym, "ticks": ticks, "count": len(ticks)}

def api_ws_status():
    with _cache_lock:
        cached_q  = list(_rt_quotes.keys())
        cached_ob = list(_rt_orderbook.keys())
    return {
        "connected":           _ws_connected,
        "subscribed_symbols":  list(_ws_subscribed_syms),
        "subscribed_channels": list(_ws_subscribed_keys),
        "cached_quotes":       cached_q,
        "cached_orderbooks":   cached_ob,
        "live_bars":           list(_live_bar.keys()),
        "watchlist_count":     len(WATCHLIST),
        "api_key_ok":          bool(DNSE_API_KEY),
    }

# ═══════════════════════════════════════════════════════════════════════════════
# HTTP Server
# ═══════════════════════════════════════════════════════════════════════════════
class FDataHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def do_GET(self):
        parsed = urlparse(self.path)
        path   = parsed.path.rstrip("/")
        params = parse_qs(parsed.query)
        try:
            if path == "/api/symbols":
                data = api_symbols(params)
            elif path == "/api/quotes":
                data = api_quotes(params)
            elif path.startswith("/api/candles/"):
                sym  = path.split("/api/candles/")[-1].upper()
                data = api_candles(sym, params)
            elif path.startswith("/api/orderbook/"):
                sym  = path.split("/api/orderbook/")[-1].upper()
                data = api_orderbook(sym)
            elif path.startswith("/api/ticks/"):
                sym  = path.split("/api/ticks/")[-1].upper()
                data = api_ticks(sym, params)
            elif path == "/api/ws_status":
                data = api_ws_status()
            elif path == "/health":
                data = {"status": "ok", "ws_connected": _ws_connected}
            else:
                self._send(404, {"error": f"Unknown: {path}"}); return
            self._send(200, data)
        except Exception as e:
            log.error(f"HTTP {path}: {e}")
            self._send(500, {"error": str(e)})

    def _send(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type",   "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("╔══════════════════════════════════════════════╗")
    print("║   FData Server v4.0 - DNSE Full Realtime     ║")
    print("╠══════════════════════════════════════════════╣")
    print(f"║  Port      : {PORT:<31}║")
    print(f"║  Watchlist : {len(WATCHLIST)} mã VN30{'+' if _extra else '':<24}║")
    print(f"║  API Key   : {'✓ OK' if DNSE_API_KEY else '✗ MISSING'}{'':28}║")
    print("╠══════════════════════════════════════════════╣")
    print("║  Endpoints:                                  ║")
    print("║  GET /api/quotes                             ║")
    print("║  GET /api/candles/{SYM}?timeframe=1m|15m|1D ║")
    print("║  GET /api/orderbook/{SYM}                    ║")
    print("║  GET /api/ticks/{SYM}                        ║")
    print("║  GET /api/ws_status                          ║")
    print("╚══════════════════════════════════════════════╝")

    if not DNSE_API_KEY:
        print("\n[WARN] Chưa có DNSE_API_KEY! Điền vào dnse/.env\n")
    else:
        ws_thread = threading.Thread(target=start_ws_thread, daemon=True, name="DNSE-WS")
        ws_thread.start()
        # Pre-warm EOD cache cho toàn bộ watchlist ngay khi khởi động
        log.info(f"[INIT] Pre-warming EOD cache cho {len(WATCHLIST)} mã...")
        for _sym in WATCHLIST:
            prefetch_eod_async(_sym)

    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        lan_ip = s.getsockname()[0]; s.close()
    except Exception:
        lan_ip = "localhost"

    print(f"\n[HTTP] http://localhost:{PORT}")
    print(f"[HTTP] http://{lan_ip}:{PORT}  ← nhập vào Flutter Settings")
    print("\nPress Ctrl+C to stop.\n")

    server = HTTPServer((HOST, PORT), FDataHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[STOP] Server stopped.")
