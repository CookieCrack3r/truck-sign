FROM python:3.15.0rc2-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install

COPY . /app

EXPOSE

ENTRYPOINT ["entrypoint.sh"]
