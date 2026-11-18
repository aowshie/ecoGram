import json
import os
import re
from dataclasses import dataclass

from .paths import BRANDING_CONFIG

API_ID = re.compile(r"[1-9][0-9]{0,9}")
API_HASH = re.compile(r"[0-9a-fA-F]{32}")


@dataclass(frozen=True)
class Branding:
    display_name: str
    bundle_id: str
    team_id: str
    url_scheme: str
    artifact_prefix: str


def branding() -> Branding:
    return Branding(**json.loads(BRANDING_CONFIG.read_text(encoding="utf-8")))


def telegram_credentials() -> tuple[str, str]:
    api_id = os.environ.get("TELEGRAM_API_ID", "").strip()
    api_hash = os.environ.get("TELEGRAM_API_HASH", "").strip()
    if not API_ID.fullmatch(api_id) or int(api_id) > 2_147_483_647:
        raise ValueError("TELEGRAM_API_ID is missing or malformed")
    if not API_HASH.fullmatch(api_hash):
        raise ValueError("TELEGRAM_API_HASH is missing or malformed")
    return api_id, api_hash


def make_configuration() -> dict:
    brand = branding()
    api_id, api_hash = telegram_credentials()
    return {
        "bundle_id": brand.bundle_id,
        "api_id": api_id,
        "api_hash": api_hash,
        "team_id": brand.team_id,
        "app_center_id": "0",
        "is_internal_build": "true",
        "is_appstore_build": "false",
        "appstore_id": "0",
        "app_specific_url_scheme": brand.url_scheme,
        "premium_iap_product_id": "",
        "enable_siri": False,
        "enable_icloud": False,
        "sg_config": "",
    }
