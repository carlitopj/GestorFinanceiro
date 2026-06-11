import sqlite3
import os
import sys

# Caminho do banco de dados ATUAL em uso (pode ser trocado em runtime via "Abrir")
_db_path = None


def get_app_dir():
    """Retorna a pasta de dados do app, multiplataforma (Android/Desktop)."""
    try:
        from kivy.app import App
        from android.storage import app_storage_path  # type: ignore
        return app_storage_path()
    except Exception:
        pass

    try:
        from kivy.app import App
        app = App.get_running_app()
        if app is not None:
            return app.user_data_dir
    except Exception:
        pass

    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))


def get_default_db_path():
    return os.path.join(get_app_dir(), "financas.db")


def set_db_path(caminho):
    """Define qual arquivo .db será usado pelas próximas operações."""
    global _db_path
    _db_path = caminho


def get_db_path():
    global _db_path
    if _db_path is None:
        _db_path = get_default_db_path()
    return _db_path


def conectar():
    caminho_db = get_db_path()
    return sqlite3.connect(caminho_db)


def criar_tabela():
    conn = conectar()
    cursor = conn.cursor()
    # Tabela de transações
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS transacoes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario TEXT,
            descricao TEXT,
            valor REAL,
            tipo TEXT,
            categoria TEXT,
            mes_ref TEXT
        )
    """)
    # Tabela de usuários
    cursor.execute("CREATE TABLE IF NOT EXISTS usuarios (nome TEXT UNIQUE)")

    # Tabela de categorias
    cursor.execute("CREATE TABLE IF NOT EXISTS categorias (nome TEXT UNIQUE)")

    # Verificar usuários padrão
    cursor.execute("SELECT COUNT(*) FROM usuarios")
    if cursor.fetchone()[0] == 0:
        for u in ["Lidiane", "Junior"]:
            cursor.execute("INSERT INTO usuarios (nome) VALUES (?)", (u,))

    # Verificar categorias padrão
    cursor.execute("SELECT COUNT(*) FROM categorias")
    if cursor.fetchone()[0] == 0:
        padrao = ["Alimentação", "Transporte", "Lazer", "Saúde", "Moradia", "Outros"]
        for cat in padrao:
            cursor.execute("INSERT INTO categorias (nome) VALUES (?)", (cat,))

    conn.commit()
    conn.close()


def buscar_usuarios():
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT nome FROM usuarios")
    nomes = [linha[0] for linha in cursor.fetchall()]
    conn.close()
    return nomes


def adicionar_usuario(nome):
    try:
        conn = conectar()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO usuarios (nome) VALUES (?)", (nome,))
        conn.commit()
        conn.close()
        return True
    except Exception:
        return False


def excluir_usuario_db(nome):
    try:
        conn = conectar()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM usuarios WHERE nome=?", (nome,))
        cursor.execute("DELETE FROM transacoes WHERE usuario=?", (nome,))
        conn.commit()
        conn.close()
        return True
    except Exception:
        return False


# FUNÇÕES DE CATEGORIA
def buscar_categorias():
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT nome FROM categorias ORDER BY nome ASC")
    res = [linha[0] for linha in cursor.fetchall()]
    conn.close()
    return res


def adicionar_categoria_db(nome):
    try:
        conn = conectar()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO categorias (nome) VALUES (?)", (nome,))
        conn.commit()
        conn.close()
        return True
    except Exception:
        return False


def excluir_categoria_db(nome):
    try:
        conn = conectar()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM categorias WHERE nome=?", (nome,))
        conn.commit()
        conn.close()
        return True
    except Exception:
        return False


def salvar_transacao(usuario, desc, valor, tipo, categoria, mes_ref):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO transacoes (usuario, descricao, valor, tipo, categoria, mes_ref) 
        VALUES (?, ?, ?, ?, ?, ?)""", (usuario, desc, valor, tipo, categoria, mes_ref))
    conn.commit()
    conn.close()


def atualizar_transacao(id_transacao, valor, tipo, categoria):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("UPDATE transacoes SET valor=?, tipo=?, categoria=? WHERE id=?",
                   (valor, tipo, categoria, id_transacao))
    conn.commit()
    conn.close()


def buscar_por_descricao_e_mes(usuario, desc, mes_ref):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT id, valor, tipo, categoria FROM transacoes WHERE usuario=? AND descricao=? AND mes_ref=?",
                   (usuario, desc, mes_ref))
    res = cursor.fetchone()
    conn.close()
    return res


def buscar_transacoes_por_mes(usuario, mes_ref):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT id, descricao, valor, tipo, categoria FROM transacoes WHERE usuario=? AND mes_ref=?",
                   (usuario, mes_ref))
    res = cursor.fetchall()
    conn.close()
    return res


def calcular_saldo_mes(usuario, mes_ref):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT tipo, valor FROM transacoes WHERE usuario=? AND mes_ref=?", (usuario, mes_ref))
    dados = cursor.fetchall()
    conn.close()
    receitas = sum(v for t, v in dados if t == "Receita")
    despesas = sum(v for t, v in dados if t == "Despesa")
    return receitas, despesas, (receitas - despesas)


def buscar_historico_grafico(usuario):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT valor, tipo, mes_ref FROM transacoes WHERE usuario=? ORDER BY id ASC", (usuario,))
    res = cursor.fetchall()
    conn.close()
    return res


def buscar_dados_anuais(usuario, ano):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("SELECT valor, tipo, mes_ref FROM transacoes WHERE usuario=? AND mes_ref LIKE ?", (usuario, f"%/{ano}"))
    res = cursor.fetchall()
    conn.close()
    return res


def deletar_transacao(id_transacao):
    conn = conectar()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM transacoes WHERE id=?", (id_transacao,))
    conn.commit()
    conn.close()


def exportar_para_excel(usuario, pasta_destino=None):
    try:
        from openpyxl import Workbook

        conn = conectar()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT mes_ref, descricao, valor, tipo, categoria FROM transacoes WHERE usuario=?",
            (usuario,))
        linhas = cursor.fetchall()
        conn.close()

        wb = Workbook()
        ws = wb.active
        ws.title = "Transações"
        ws.append(["mes_ref", "descricao", "valor", "tipo", "categoria"])
        for linha in linhas:
            ws.append(list(linha))

        nome_arquivo = f"relatorio_financas_{usuario}.xlsx"
        if pasta_destino:
            nome_arquivo = os.path.join(pasta_destino, nome_arquivo)
        else:
            nome_arquivo = os.path.join(get_app_dir(), nome_arquivo)
        wb.save(nome_arquivo)
        return True, nome_arquivo
    except Exception as e:
        return False, str(e)
