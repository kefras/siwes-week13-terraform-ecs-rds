"""Optional real local MySQL/TLS smoke test. No AWS access. Requires Docker and cryptography.
Run from project root: evidence/test-venv/Scripts/python.exe app/tests/local_mysql.py
"""
import datetime
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import time
import uuid

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

root = Path(__file__).resolve().parents[2]
run_id = 'week13-local-' + uuid.uuid4().hex[:10]
certs = root / 'evidence' / run_id
certs.mkdir(parents=True)
network = run_id
mysql = run_id + '-mysql'
app = run_id + '-app'
password = secrets.token_urlsafe(24)
created = []

def docker(*args, check=True):
    result = subprocess.run(['docker', *args], capture_output=True, text=True)
    if check and result.returncode:
        raise RuntimeError('Docker operation failed: ' + args[0] + '\n' + result.stderr)
    return result

def keyfile(path, key):
    path.write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL, serialization.NoEncryption()))

now = datetime.datetime.now(datetime.timezone.utc)
ca_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
ca_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Week13 disposable test CA')])
ca = (x509.CertificateBuilder().subject_name(ca_name).issuer_name(ca_name)
      .public_key(ca_key.public_key()).serial_number(x509.random_serial_number())
      .not_valid_before(now - datetime.timedelta(minutes=5)).not_valid_after(now + datetime.timedelta(days=1))
      .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
      .sign(ca_key, hashes.SHA256()))
server_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
server = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'mysql')]))
          .issuer_name(ca_name).public_key(server_key.public_key()).serial_number(x509.random_serial_number())
          .not_valid_before(now - datetime.timedelta(minutes=5)).not_valid_after(now + datetime.timedelta(days=1))
          .add_extension(x509.SubjectAlternativeName([x509.DNSName('mysql')]), critical=False)
          .sign(ca_key, hashes.SHA256()))
(certs / 'ca.pem').write_bytes(ca.public_bytes(serialization.Encoding.PEM))
(certs / 'server.pem').write_bytes(server.public_bytes(serialization.Encoding.PEM))
keyfile(certs / 'server-key.pem', server_key)

try:
    docker('network', 'create', network)
    docker('run', '-d', '--name', mysql, '--network', network, '--network-alias', 'mysql',
           '--tmpfs', '/var/lib/mysql', '--mount', f'type=bind,source={certs},target=/test-certs,readonly',
           '-e', 'MYSQL_ROOT_PASSWORD=' + password, '-e', 'MYSQL_DATABASE=appdb',
           '-e', 'MYSQL_USER=week13test', '-e', 'MYSQL_PASSWORD=' + password,
           'mysql:8.4', '--ssl-ca=/test-certs/ca.pem', '--ssl-cert=/test-certs/server.pem',
           '--ssl-key=/test-certs/server-key.pem', '--require-secure-transport=ON')
    created.append(mysql)
    for _ in range(90):
        probe = docker('exec', mysql, 'mysqladmin', 'ping', '--silent', check=False)
        if probe.returncode == 0:
            break
        time.sleep(2)
    else:
        raise RuntimeError('Local MySQL did not initialize')

    # Run exactly the ECS probe command from the actual Terraform source.
    source = (root / 'modules/ecs/main.tf').read_text(encoding='utf-8')
    command = re.search(r'command\s*=\s*\["CMD", "python", "-c", "([^"]+)"\]', source).group(1)
    command = command.replace('${var.container_port}', '8000').replace('${var.health_check_path}', '/health')
    docker('run', '-d', '--name', app, '--read-only', '--network', network,
           '--mount', f'type=bind,source={certs / "ca.pem"},target=/test-ca.pem,readonly',
           '-e', 'DB_HOST=mysql', '-e', 'DB_PORT=3306', '-e', 'DB_NAME=appdb',
           '-e', 'DB_USERNAME=week13test', '-e', 'DB_PASSWORD=' + password,
           '-e', 'DB_SSL_CA=/test-ca.pem', '-e', 'APP_ENV=local-test', 'week13-ecs-app:v2')
    created.append(app)
    for _ in range(40):
        result = docker('exec', app, 'python', '-c', command, check=False)
        if result.returncode == 0:
            break
        time.sleep(2)
    else:
        raise RuntimeError('Application never passed the ECS health probe')
    print('PASS: nonroot/read-only app startup + real MySQL SELECT 1 over verified TLS')
    print('PASS: exact Terraform ECS health command accepts database=connected')
    logs = docker('logs', app)
    assert 'Database startup check succeeded' in logs.stderr + logs.stdout

    # Stop only this disposable DB: health must become HTTP 503 and probe must fail.
    docker('stop', '-t', '5', mysql)
    failure = docker('exec', app, 'python', '-c', command, check=False)
    assert failure.returncode != 0, 'Probe accepted a database outage'
    status = docker('exec', app, 'python', '-c',
        "import urllib.request,urllib.error;\ntry: urllib.request.urlopen('http://127.0.0.1:8000/health')\nexcept urllib.error.HTTPError as e: assert e.code == 503; print('503 verified')")
    assert '503 verified' in status.stdout
    print('PASS: database outage causes HTTP 503 and ECS health failure')
    (root / 'evidence/local-mysql-v2.txt').write_text('Real local TLS MySQL integration: PASS\nExact ECS probe: PASS\nDatabase outage HTTP 503/probe failure: PASS\nNot an RDS test.\n', encoding='utf-8')
finally:
    for container in reversed(created):
        docker('rm', '-f', container, check=False)
    docker('network', 'rm', network, check=False)
    # Delete only test-generated material in the exact per-run evidence directory.
    for name in ('ca.pem', 'server.pem', 'server-key.pem'):
        (certs / name).unlink(missing_ok=True)
    certs.rmdir()
