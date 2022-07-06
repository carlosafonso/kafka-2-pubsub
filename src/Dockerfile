FROM python:3.10-slim AS build-env

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

ENV PYTHONPATH=/usr/local/lib/python3.10/site-packages
