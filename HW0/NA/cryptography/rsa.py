from pwn import *
from Crypto.PublicKey import RSA
from tqdm import tqdm

key = RSA.generate(4096)

target = remote("140.112.91.1", 48763)

print(target.recvuntil("n: "))

target.sendline(str(key.n))

print(target.recvuntil("e: "))

target.sendline(str(key.e))

print(target.recvline())
print(target.recvuntil(": "))
secret = int(target.recvall()[:-1])
secret = int(secret)

print(secret)

dp = key.d % (key.p - 1)
dq = key.d % (key.q - 1)
qinv = pow(key.q, -1, key.p)

print("dp: ", dp)
print("dq: ", dq)
print("qinv: ", qinv)

m1 = pow(secret, dp, key.p)
m2 = pow(secret, dq, key.q)

h = (qinv*(m1 - m2)) % key.p
m = m2 + h * key.q

m = m.to_bytes(m.bit_length() // 8 + 1).decode()

print(m)