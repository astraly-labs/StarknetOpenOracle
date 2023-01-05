FROM python:3.7

WORKDIR /

COPY ./client . 
COPY requirements.txt .
COPY build/OpenOraclePublisher_abi.json ./build/


RUN pip install -r requirements.txt

CMD ["python", "main.py"]