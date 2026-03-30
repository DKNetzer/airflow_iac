from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

def say_hello():
    print("Hello from GKE Autopilot! Your Airflow DDL is complete.")

with DAG(
    '01_hello_world_gke',
    default_args={'retries': 1},
    description='First DAG for DKNetzer Airflow',
    schedule_interval=timedelta(days=1),
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['example'],
) as dag:

    hello_task = PythonOperator(
        task_id='hello_task',
        python_callable=say_hello,
    )