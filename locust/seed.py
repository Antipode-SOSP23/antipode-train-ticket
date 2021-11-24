import os
import sys
import requests
from faker import Faker
from faker.providers import ssn, phone_number
from datetime import datetime, date
import yaml
from pprint import pprint as pp
import multiprocessing
from tqdm import tqdm
import time


AUTH_SERVICE_URL = os.environ['AUTH_SERVICE_URL']
ORDER_SERVICE_URL = os.environ['ORDER_SERVICE_URL']
INSIDE_PAYMENT_SERVICE_URL = os.environ['INSIDE_PAYMENT_SERVICE_URL']
TT_USERNAME = os.environ['TT_USERNAME']
TT_PASSWORD = os.environ['TT_PASSWORD']
SEED_SIZE = int(os.environ['SEED_SIZE'])
DEPLOY_TAG = os.environ['DEPLOY_TAG']
WORKER_ID = os.environ['WORKER_ID']

def auth_user():
  # login
  auth_url = f"{AUTH_SERVICE_URL}/api/v1/users/login"
  params = { "username": TT_USERNAME, "password": TT_PASSWORD, "verificationCode": "" }
  r = requests.post(auth_url, json=params)
  user_id = r.json()['data']['userId']
  auth_token = r.json()['data']['token']
  return user_id, auth_token

def create_order_and_pay(args):
  user_id, auth_token = args
  create_order_url = f"{ORDER_SERVICE_URL}/api/v1/orderservice/order"
  pay_order_url = f"{INSIDE_PAYMENT_SERVICE_URL}/api/v1/inside_pay_service/inside_payment"
  headers = { 'Authorization': 'Bearer ' + auth_token }
  fake = Faker()
  TODAY = date.today()

  # Create order
  try:
    order_params = {
      "accountId": user_id,
      #
      "contactsName": fake.name(),
      "contactsDocumentNumber": fake.ssn(),
      "documentType": 1, # ID Card
      # /admin_station.html
      "from": 'shanghai',
      "to": 'suzhou',
      # TRIP ID - /admin_travel.html
      "trainNumber": 'D1345',
      #
      "seatClass": 1, # BUSINESS
      "coachNumber": 22,
      "seatNumber": fake.bothify(text='##?', letters='ABCDEF'),
      #
      "boughtDate": datetime.now().isoformat().replace("+00:00", "Z"),
      "travelDate": datetime(year=TODAY.year, month=TODAY.month, day=TODAY.day).isoformat().replace("+00:00", "Z"),
      "travelTime": datetime.now().isoformat().replace("+00:00", "Z"),
      #
      "price": str(100.0),
      "status": 0, # NOT PAID
    }
    r = requests.post(create_order_url, headers=headers, json=order_params)
    if r.status_code != 200:
      print("[ERROR] Failed to create order")
      return None

    order_id = r.json()['data']['id']

    # Pay order
    params = {
      "userId": user_id,
      "orderId": order_id,
      "tripId": order_params['trainNumber'],
      "price": order_params['price'],
    }
    r = requests.post(pay_order_url, headers=headers, json=params)
    if r.status_code != 200:
      print("[ERROR] Failed to pay order")
      return None

    return order_id
  except requests.exceptions.ConnectionError as e:
    print("[ERROR] Failed to create and pay order")
    return None

user_id, auth_token = auth_user()

order_ids = []
with multiprocessing.Pool(processes=multiprocessing.cpu_count()*2) as p:
  args_range = [ (user_id,auth_token) for i in range(SEED_SIZE) ]
  for i,order_id in enumerate(p.imap_unordered(create_order_and_pay, args_range)):
    order_ids.append(order_id)
    print(f"\tSeed [{i+1}/{SEED_SIZE}] -- {order_id}", flush=True) # hack to print to stdout progress bar steps

# export order ids to yaml
seed_filepath = f"{DEPLOY_TAG}_seed_{WORKER_ID}.yml"
with open(seed_filepath, 'w+') as f:
  yaml.safe_dump(order_ids, f, default_flow_style=False)
print(f"[SAVED] {seed_filepath}")