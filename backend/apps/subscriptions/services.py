import json
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from urllib import error, parse, request

from django.conf import settings


class PaymentGatewayError(Exception):
    pass


@dataclass(frozen=True)
class PaymentSession:
    tran_id: str
    gateway_url: str
    mode: str


def sslcommerz_enabled() -> bool:
    return bool(settings.SSLCOMMERZ_STORE_ID and settings.SSLCOMMERZ_STORE_PASSWORD)


def sslcommerz_base_url() -> str:
    if settings.SSLCOMMERZ_SANDBOX:
        return "https://sandbox.sslcommerz.com"
    return "https://securepay.sslcommerz.com"


def subscription_amount_bdt() -> str:
    amount = Decimal(str(settings.SUBSCRIPTION_PRICE_BDT)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )
    return format(amount, "f")


def create_sslcommerz_session(*, payload: dict[str, str]) -> PaymentSession:
    encoded = parse.urlencode(payload).encode("utf-8")
    endpoint = f"{sslcommerz_base_url()}/gwprocess/v4/api.php"
    req = request.Request(endpoint, data=encoded, method="POST")

    try:
        with request.urlopen(req, timeout=20) as response:
            raw_body = response.read().decode("utf-8")
    except error.URLError as exc:
        raise PaymentGatewayError(f"Could not reach SSLCommerz: {exc}") from exc

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise PaymentGatewayError("SSLCommerz returned an invalid JSON response.") from exc

    gateway_url = body.get("GatewayPageURL")
    if not gateway_url:
        reason = body.get("failedreason") or body.get("status") or "unknown error"
        raise PaymentGatewayError(f"SSLCommerz session init failed: {reason}")

    return PaymentSession(
        tran_id=payload["tran_id"],
        gateway_url=gateway_url,
        mode="sslcommerz",
    )


def validate_sslcommerz_payment(*, val_id: str) -> dict:
    query = parse.urlencode(
        {
            "val_id": val_id,
            "store_id": settings.SSLCOMMERZ_STORE_ID,
            "store_passwd": settings.SSLCOMMERZ_STORE_PASSWORD,
            "v": 1,
            "format": "json",
        }
    )
    endpoint = f"{sslcommerz_base_url()}/validator/api/validationserverAPI.php?{query}"

    try:
        with request.urlopen(endpoint, timeout=20) as response:
            raw_body = response.read().decode("utf-8")
    except error.URLError as exc:
        raise PaymentGatewayError(f"Could not validate SSLCommerz payment: {exc}") from exc

    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise PaymentGatewayError("SSLCommerz validation returned invalid JSON.") from exc
