import sqlite3

DB_ATUAL = "financas.db"

def definir_banco(caminho):
    global DB_ATUAL
    DB_ATUAL = caminho

def conectar():
    return sqlite3.connect(DB_ATUAL)
