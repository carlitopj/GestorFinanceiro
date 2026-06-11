import os
import shutil
from datetime import datetime

from kivy.lang import Builder
from kivy.metrics import dp
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.image import Image as KivyImage
from kivy.core.window import Window
from kivy.utils import platform

from kivymd.app import MDApp
from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.button import MDRaisedButton, MDIconButton
from kivymd.uix.textfield import MDTextField
from kivymd.uix.label import MDLabel
from kivymd.uix.dialog import MDDialog
from kivymd.uix.menu import MDDropdownMenu
from kivymd.uix.list import OneLineListItem, ThreeLineListItem
from kivymd.uix.card import MDCard
from kivymd.uix.scrollview import MDScrollView
from kivymd.uix.toolbar import MDTopAppBar
from kivymd.uix.snackbar import Snackbar

import database as db

# matplotlib em modo "Agg" -> gera imagem sem precisar de janela
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


MESES = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
         "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]


def formatar_real(valor):
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def grafico_path(nome):
    return os.path.join(db.get_app_dir(), nome)


def gerar_grafico_barras(usuario):
    dados = db.buscar_historico_grafico(usuario)
    if not dados:
        return None
    resumo = {}
    for v, t, m in dados:
        if m not in resumo:
            resumo[m] = {"Receita": 0.0, "Despesa": 0.0}
        resumo[m][t] += float(v)
    meses_ord = sorted(resumo.keys(), key=lambda x: datetime.strptime(x, "%m/%Y"))
    recs = [resumo[m]["Receita"] for m in meses_ord]
    desps = [resumo[m]["Despesa"] for m in meses_ord]

    fig, ax = plt.subplots(figsize=(8, 5))
    x = range(len(meses_ord))
    r1 = ax.bar([i - 0.17 for i in x], recs, 0.35, label='Receitas', color='#27ae60')
    r2 = ax.bar([i + 0.17 for i in x], desps, 0.35, label='Despesas', color='#e74c3c')
    ax.bar_label(r1, padding=3, fmt='R$%.0f', fontsize=7, fontweight='bold')
    ax.bar_label(r2, padding=3, fmt='R$%.0f', fontsize=7, fontweight='bold')
    ax.set_xticks(list(x))
    ax.set_xticklabels(meses_ord, rotation=45, ha="right")
    ax.legend()
    fig.tight_layout()

    caminho = grafico_path("grafico_barras.png")
    fig.savefig(caminho, dpi=120)
    plt.close(fig)
    return caminho


def gerar_grafico_pizza(usuario, mes_ref):
    dados = db.buscar_transacoes_por_mes(usuario, mes_ref)
    gastos = {}
    for item in dados:
        if item[3] == "Despesa":
            cat = item[4] if item[4] else "Outros"
            gastos[cat] = gastos.get(cat, 0) + float(item[2])
    if not gastos:
        return None

    fig, ax = plt.subplots(figsize=(6, 6))
    ax.pie(gastos.values(), labels=gastos.keys(), autopct='%1.1f%%',
           startangle=140, colors=plt.cm.Paired.colors)
    ax.set_title(f"Gastos por Categoria - {mes_ref}")
    fig.tight_layout()

    caminho = grafico_path("grafico_pizza.png")
    fig.savefig(caminho, dpi=120)
    plt.close(fig)
    return caminho


def gerar_grafico_anual(usuario, ano):
    dados = db.buscar_dados_anuais(usuario, ano)
    if not dados:
        return None
    resumo = {f"{i:02d}/{ano}": {"Receita": 0.0, "Despesa": 0.0} for i in range(1, 13)}
    for v, t, m in dados:
        if m in resumo:
            resumo[m][t] += float(v)
    meses = sorted(resumo.keys())
    recs = [resumo[m]["Receita"] for m in meses]
    desps = [resumo[m]["Despesa"] for m in meses]

    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(range(1, 13), recs, marker='o', label="Receitas", color="green")
    ax.plot(range(1, 13), desps, marker='o', label="Despesas", color="red")
    for i, v in enumerate(recs):
        if v > 0:
            ax.text(i + 1, v, f'R${v:.0f}', ha='center', va='bottom', fontsize=8)
    ax.legend()
    ax.set_title(f"Evolução Anual {ano}")
    ax.grid(True)
    fig.tight_layout()

    caminho = grafico_path("grafico_anual.png")
    fig.savefig(caminho, dpi=120)
    plt.close(fig)
    return caminho


KV = """
ScreenManager:
    MainScreen:
    ExtratoScreen:
    GraficoScreen:


<MainScreen>:
    name: "main"

    BoxLayout:
        orientation: "vertical"

        MDTopAppBar:
            title: "Gestor Financeiro Mensal"
            elevation: 4
            right_action_items: [["folder-open", lambda x: app.abrir_arquivo()], ["content-save", lambda x: app.salvar_como()], ["dots-vertical", lambda x: app.abrir_menu_principal(x)]]

        ScrollView:
            MDBoxLayout:
                orientation: "vertical"
                adaptive_height: True
                padding: dp(16)
                spacing: dp(12)

                MDCard:
                    orientation: "vertical"
                    padding: dp(16)
                    size_hint_y: None
                    height: dp(90)
                    md_bg_color: 0.12, 0.12, 0.12, 1
                    radius: [16, 16, 16, 16]

                    MDLabel:
                        id: label_saldo
                        text: "Saldo: R$ 0,00"
                        halign: "center"
                        font_style: "H5"
                        theme_text_color: "Custom"
                        text_color: 0.4, 0.9, 0.5, 1

                MDBoxLayout:
                    adaptive_height: True
                    spacing: dp(8)

                    MDRaisedButton:
                        id: btn_usuario
                        text: "Usuário: --"
                        size_hint_x: 0.5
                        on_release: app.abrir_menu_usuario(self)

                    MDRaisedButton:
                        id: btn_mes
                        text: "Mês: --"
                        size_hint_x: 0.5
                        on_release: app.abrir_menu_mes(self)

                MDTextField:
                    id: entry_desc
                    hint_text: "Descrição do item"
                    on_text: app.verificar_existente(self.text)

                MDTextField:
                    id: entry_valor
                    hint_text: "Valor (R$ 0,00)"
                    input_filter: None

                MDBoxLayout:
                    adaptive_height: True
                    spacing: dp(8)

                    MDRaisedButton:
                        id: btn_categoria
                        text: "Categoria: Outros"
                        size_hint_x: 0.7
                        on_release: app.abrir_menu_categoria(self)

                    MDIconButton:
                        icon: "plus"
                        on_release: app.adicionar_nova_categoria()

                    MDIconButton:
                        icon: "minus"
                        theme_icon_color: "Custom"
                        icon_color: 0.9, 0.3, 0.3, 1
                        on_release: app.excluir_categoria_atual()

                MDRaisedButton:
                    id: btn_tipo
                    text: "Tipo: Despesa"
                    size_hint_x: 1
                    on_release: app.abrir_menu_tipo(self)

                MDRaisedButton:
                    text: "Salvar / Atualizar Lançamento"
                    size_hint_x: 1
                    md_bg_color: 0.16, 0.5, 0.9, 1
                    on_release: app.registrar()

                MDRaisedButton:
                    text: "Ver Extrato do Mês"
                    size_hint_x: 1
                    md_bg_color: 0.2, 0.29, 0.37, 1
                    on_release: app.abrir_extrato()

                MDRaisedButton:
                    text: "Gráfico de Barras Mensal"
                    size_hint_x: 1
                    md_bg_color: 0.56, 0.27, 0.68, 1
                    on_release: app.exibir_grafico("barras")

                MDRaisedButton:
                    text: "Gastos por Categoria"
                    size_hint_x: 1
                    md_bg_color: 0.83, 0.33, 0, 1
                    on_release: app.exibir_grafico("pizza")

                MDRaisedButton:
                    text: "Relatório de Evolução Anual"
                    size_hint_x: 1
                    md_bg_color: 0.16, 0.5, 0.73, 1
                    on_release: app.exibir_grafico("anual")

                MDRaisedButton:
                    text: "Exportar para Excel"
                    size_hint_x: 1
                    md_bg_color: 0.15, 0.68, 0.38, 1
                    on_release: app.exportar()


<ExtratoScreen>:
    name: "extrato"

    BoxLayout:
        orientation: "vertical"

        MDTopAppBar:
            title: "Extrato do Mês"
            left_action_items: [["arrow-left", lambda x: app.voltar_main()]]

        ScrollView:
            MDBoxLayout:
                id: lista_extrato
                orientation: "vertical"
                adaptive_height: True
                padding: dp(8)
                spacing: dp(4)


<GraficoScreen>:
    name: "grafico"

    BoxLayout:
        orientation: "vertical"

        MDTopAppBar:
            title: "Gráfico"
            left_action_items: [["arrow-left", lambda x: app.voltar_main()]]

        ScrollView:
            MDBoxLayout:
                orientation: "vertical"
                adaptive_height: True
                padding: dp(8)

                Image:
                    id: img_grafico
                    size_hint_y: None
                    height: dp(400)
                    allow_stretch: True
"""


class MainScreen(MDScreen):
    pass


class ExtratoScreen(MDScreen):
    pass


class GraficoScreen(MDScreen):
    pass


class GestorApp(MDApp):

    def build(self):
        self.theme_cls.theme_style = "Light"
        self.theme_cls.primary_palette = "Blue"

        db.criar_tabela()

        self.id_edicao = None
        self.usuarios = db.buscar_usuarios()
        self.categorias = db.buscar_categorias()
        self.usuario_atual = self.usuarios[0] if self.usuarios else "Usuário"
        self.mes_atual = MESES[datetime.now().month - 1]
        self.tipo_atual = "Despesa"
        self.categoria_atual = "Outros" if "Outros" in self.categorias else (
            self.categorias[0] if self.categorias else "Outros")

        self.menu_usuario = None
        self.menu_mes = None
        self.menu_categoria = None
        self.menu_tipo = None
        self.menu_principal = None
        self.dialog = None

        self.root_widget = Builder.load_string(KV)
        return self.root_widget

    def on_start(self):
        self.atualizar_labels()
        self.atualizar_dashboard()

    # ---------------------------------------------------------
    # Helpers de tela
    # ---------------------------------------------------------
    def get_main_screen(self):
        return self.root_widget.get_screen("main")

    def voltar_main(self):
        self.root_widget.current = "main"

    def get_mes_referencia(self):
        mes_num = MESES.index(self.mes_atual) + 1
        return f"{mes_num:02d}/{datetime.now().year}"

    def atualizar_labels(self):
        screen = self.get_main_screen()
        screen.ids.btn_usuario.text = f"Usuário: {self.usuario_atual}"
        screen.ids.btn_mes.text = f"Mês: {self.mes_atual}"
        screen.ids.btn_categoria.text = f"Categoria: {self.categoria_atual}"
        screen.ids.btn_tipo.text = f"Tipo: {self.tipo_atual}"

    def mostrar_aviso(self, texto):
        Snackbar(text=texto).open()

    # ---------------------------------------------------------
    # Menus suspensos
    # ---------------------------------------------------------
    def abrir_menu_usuario(self, caller):
        items = [{
            "text": u,
            "on_release": lambda x=u: self.selecionar_usuario(x)
        } for u in self.usuarios]
        self.menu_usuario = MDDropdownMenu(caller=caller, items=items, width_mult=4)
        self.menu_usuario.open()

    def selecionar_usuario(self, usuario):
        self.usuario_atual = usuario
        self.atualizar_labels()
        self.atualizar_dashboard()
        if self.menu_usuario:
            self.menu_usuario.dismiss()

    def abrir_menu_mes(self, caller):
        items = [{
            "text": m,
            "on_release": lambda x=m: self.selecionar_mes(x)
        } for m in MESES]
        self.menu_mes = MDDropdownMenu(caller=caller, items=items, width_mult=4)
        self.menu_mes.open()

    def selecionar_mes(self, mes):
        self.mes_atual = mes
        self.atualizar_labels()
        self.atualizar_dashboard()
        if self.menu_mes:
            self.menu_mes.dismiss()

    def abrir_menu_categoria(self, caller):
        items = [{
            "text": c,
            "on_release": lambda x=c: self.selecionar_categoria(x)
        } for c in self.categorias]
        self.menu_categoria = MDDropdownMenu(caller=caller, items=items, width_mult=4)
        self.menu_categoria.open()

    def selecionar_categoria(self, cat):
        self.categoria_atual = cat
        self.atualizar_labels()
        if self.menu_categoria:
            self.menu_categoria.dismiss()

    def abrir_menu_tipo(self, caller):
        items = [{
            "text": t,
            "on_release": lambda x=t: self.selecionar_tipo(x)
        } for t in ["Despesa", "Receita"]]
        self.menu_tipo = MDDropdownMenu(caller=caller, items=items, width_mult=4)
        self.menu_tipo.open()

    def selecionar_tipo(self, tipo):
        self.tipo_atual = tipo
        self.atualizar_labels()
        if self.menu_tipo:
            self.menu_tipo.dismiss()

    def abrir_menu_principal(self, caller):
        items = [
            {"text": "Novo Usuário", "on_release": lambda: self.fechar_e(self.dialog_novo_usuario)},
            {"text": "Excluir Usuário Atual", "on_release": lambda: self.fechar_e(self.excluir_usuario_atual)},
        ]
        self.menu_principal = MDDropdownMenu(caller=caller, items=items, width_mult=4)
        self.menu_principal.open()

    def fechar_e(self, func):
        if self.menu_principal:
            self.menu_principal.dismiss()
        func()

    # ---------------------------------------------------------
    # Categorias
    # ---------------------------------------------------------
    def adicionar_nova_categoria(self):
        self.dialog_input("Nova Categoria", "Nome da categoria", self._criar_categoria)

    def _criar_categoria(self, texto):
        nova = texto.strip().capitalize()
        if not nova:
            return
        if db.adicionar_categoria_db(nova):
            self.categorias = db.buscar_categorias()
            self.categoria_atual = nova
            self.atualizar_labels()
        else:
            self.mostrar_aviso("Categoria já existe.")

    def excluir_categoria_atual(self):
        cat = self.categoria_atual
        if cat in ["Outros", "Alimentação"]:
            self.mostrar_aviso("Esta categoria não pode ser excluída.")
            return
        self.dialog_confirmar(
            "Confirmar",
            f"Deseja excluir a categoria '{cat}'?",
            lambda: self._excluir_categoria(cat)
        )

    def _excluir_categoria(self, cat):
        if db.excluir_categoria_db(cat):
            self.categorias = db.buscar_categorias()
            self.categoria_atual = self.categorias[0] if self.categorias else "Outros"
            self.atualizar_labels()
        else:
            self.mostrar_aviso("Não foi possível excluir a categoria.")

    # ---------------------------------------------------------
    # Lançamentos
    # ---------------------------------------------------------
    def registrar(self):
        screen = self.get_main_screen()
        desc = screen.ids.entry_desc.text.strip()
        valor_raw = screen.ids.entry_valor.text.strip()

        if not desc or not valor_raw:
            self.mostrar_aviso("Preencha descrição e valor.")
            return

        try:
            valor_limpo = valor_raw.upper().replace("R$", "").strip()
            if "." in valor_limpo and "," in valor_limpo:
                valor_limpo = valor_limpo.replace(".", "")
            valor_limpo = valor_limpo.replace(",", ".")
            valor_final = float(valor_limpo)

            mes_ref = self.get_mes_referencia()
            if self.id_edicao:
                db.atualizar_transacao(self.id_edicao, valor_final, self.tipo_atual, self.categoria_atual)
            else:
                db.salvar_transacao(self.usuario_atual, desc, valor_final, self.tipo_atual,
                                     self.categoria_atual, mes_ref)

            self.id_edicao = None
            screen.ids.entry_desc.text = ""
            screen.ids.entry_valor.text = ""
            self.atualizar_dashboard()
            self.mostrar_aviso("Lançamento salvo!")
        except Exception:
            self.mostrar_aviso("Formato de valor inválido!")

    def verificar_existente(self, texto):
        desc = texto.strip()
        if len(desc) >= 2:
            res = db.buscar_por_descricao_e_mes(self.usuario_atual, desc, self.get_mes_referencia())
            if res:
                self.id_edicao = res[0]
                screen = self.get_main_screen()
                screen.ids.entry_valor.text = str(res[1])
                self.tipo_atual = res[2]
                if len(res) > 3 and res[3]:
                    self.categoria_atual = res[3]
                self.atualizar_labels()
            else:
                self.id_edicao = None

    def atualizar_dashboard(self):
        rec, desp, sal = db.calcular_saldo_mes(self.usuario_atual, self.get_mes_referencia())
        screen = self.get_main_screen()
        screen.ids.label_saldo.text = f"Saldo: {formatar_real(sal)}"
        if sal >= 0:
            screen.ids.label_saldo.text_color = (0.4, 0.9, 0.5, 1)
        else:
            screen.ids.label_saldo.text_color = (0.9, 0.3, 0.3, 1)

    # ---------------------------------------------------------
    # Extrato
    # ---------------------------------------------------------
    def abrir_extrato(self):
        screen = self.root_widget.get_screen("extrato")
        screen.ids.lista_extrato.clear_widgets()

        dados = db.buscar_transacoes_por_mes(self.usuario_atual, self.get_mes_referencia())
        if not dados:
            screen.ids.lista_extrato.add_widget(
                MDLabel(text="Nenhum lançamento neste mês.", halign="center")
            )
        else:
            for item in dados:
                id_, descricao, valor, tipo, categoria = item
                cor = "Receita" if tipo == "Receita" else "Despesa"
                texto = f"{descricao}\nR$ {valor:.2f} - {tipo} - {categoria}"
                lbl = ThreeLineListItem(
                    text=descricao,
                    secondary_text=f"R$ {valor:.2f}  |  {tipo}",
                    tertiary_text=f"Categoria: {categoria}",
                    on_release=lambda x, item_id=id_: self.confirmar_exclusao(item_id)
                )
                screen.ids.lista_extrato.add_widget(lbl)

        self.root_widget.current = "extrato"

    def confirmar_exclusao(self, id_transacao):
        self.dialog_confirmar(
            "Excluir lançamento",
            "Toque novamente para excluir este item, ou cancele.",
            lambda: self._excluir_transacao(id_transacao)
        )

    def _excluir_transacao(self, id_transacao):
        db.deletar_transacao(id_transacao)
        self.atualizar_dashboard()
        self.abrir_extrato()

    # ---------------------------------------------------------
    # Gráficos
    # ---------------------------------------------------------
    def exibir_grafico(self, tipo):
        caminho = None
        if tipo == "barras":
            caminho = gerar_grafico_barras(self.usuario_atual)
        elif tipo == "pizza":
            caminho = gerar_grafico_pizza(self.usuario_atual, self.get_mes_referencia())
        elif tipo == "anual":
            caminho = gerar_grafico_anual(self.usuario_atual, datetime.now().year)

        if not caminho:
            self.mostrar_aviso("Sem dados suficientes para gerar o gráfico.")
            return

        screen = self.root_widget.get_screen("grafico")
        screen.ids.img_grafico.source = ""
        screen.ids.img_grafico.source = caminho
        screen.ids.img_grafico.reload()
        self.root_widget.current = "grafico"

    # ---------------------------------------------------------
    # Usuários
    # ---------------------------------------------------------
    def dialog_novo_usuario(self):
        self.dialog_input("Novo Usuário", "Nome do usuário", self._criar_usuario)

    def _criar_usuario(self, texto):
        nome = texto.strip()
        if nome and db.adicionar_usuario(nome):
            self.usuarios = db.buscar_usuarios()
            self.usuario_atual = nome
            self.atualizar_labels()
            self.atualizar_dashboard()
        else:
            self.mostrar_aviso("Não foi possível adicionar o usuário.")

    def excluir_usuario_atual(self):
        user = self.usuario_atual
        if len(self.usuarios) <= 1:
            self.mostrar_aviso("É necessário manter ao menos um usuário.")
            return
        self.dialog_confirmar(
            "Confirmar",
            f"Excluir usuário '{user}' e todos os seus lançamentos?",
            lambda: self._excluir_usuario(user)
        )

    def _excluir_usuario(self, user):
        if db.excluir_usuario_db(user):
            self.usuarios = db.buscar_usuarios()
            self.usuario_atual = self.usuarios[0] if self.usuarios else "Usuário"
            self.atualizar_labels()
            self.atualizar_dashboard()

    # ---------------------------------------------------------
    # Exportar Excel
    # ---------------------------------------------------------
    def exportar(self):
        sucesso, res = db.exportar_para_excel(self.usuario_atual)
        if sucesso:
            self.mostrar_aviso(f"Exportado: {res}")
        else:
            self.mostrar_aviso(f"Erro ao exportar: {res}")

    # ---------------------------------------------------------
    # Abrir / Salvar arquivo .db (Android - SAF / plyer)
    # ---------------------------------------------------------
    def abrir_arquivo(self):
        try:
            from plyer import filechooser
            filechooser.open_file(
                on_selection=self._on_arquivo_selecionado,
                filters=["*.db"]
            )
        except Exception as e:
            self.mostrar_aviso(f"Seletor de arquivos indisponível: {e}")

    def _on_arquivo_selecionado(self, selection):
        if not selection:
            return
        origem = selection[0]
        try:
            destino = os.path.join(db.get_app_dir(), "financas.db")
            shutil.copy(origem, destino)
            self._origem_db_externo = origem
            db.set_db_path(destino)
            db.criar_tabela()

            self.usuarios = db.buscar_usuarios()
            self.categorias = db.buscar_categorias()
            self.usuario_atual = self.usuarios[0] if self.usuarios else "Usuário"
            self.categoria_atual = "Outros" if "Outros" in self.categorias else (
                self.categorias[0] if self.categorias else "Outros")
            self.atualizar_labels()
            self.atualizar_dashboard()
            self.mostrar_aviso("Arquivo carregado com sucesso!")
        except Exception as e:
            self.mostrar_aviso(f"Erro ao abrir arquivo: {e}")

    def salvar_como(self):
        """Copia o financas.db atual de volta para a pasta original (ou outra escolhida)."""
        try:
            from plyer import filechooser
            filechooser.choose_dir(on_selection=self._on_pasta_destino_selecionada)
        except Exception as e:
            self.mostrar_aviso(f"Seletor de pastas indisponível: {e}")

    def _on_pasta_destino_selecionada(self, selection):
        if not selection:
            return
        pasta_destino = selection[0]
        try:
            origem = db.get_db_path()
            destino = os.path.join(pasta_destino, "financas.db")
            shutil.copy(origem, destino)
            self.mostrar_aviso(f"Salvo em: {destino}")
        except Exception as e:
            self.mostrar_aviso(f"Erro ao salvar: {e}")

    # ---------------------------------------------------------
    # Diálogos genéricos
    # ---------------------------------------------------------
    def dialog_confirmar(self, titulo, texto, callback_sim):
        if self.dialog:
            self.dialog.dismiss()

        def _sim(*args):
            self.dialog.dismiss()
            callback_sim()

        def _nao(*args):
            self.dialog.dismiss()

        self.dialog = MDDialog(
            title=titulo,
            text=texto,
            buttons=[
                MDRaisedButton(text="Cancelar", on_release=_nao),
                MDRaisedButton(text="Confirmar", on_release=_sim),
            ],
        )
        self.dialog.open()

    def dialog_input(self, titulo, hint, callback):
        if self.dialog:
            self.dialog.dismiss()

        campo = MDTextField(hint_text=hint)

        def _ok(*args):
            self.dialog.dismiss()
            callback(campo.text)

        def _cancelar(*args):
            self.dialog.dismiss()

        self.dialog = MDDialog(
            title=titulo,
            type="custom",
            content_cls=campo,
            buttons=[
                MDRaisedButton(text="Cancelar", on_release=_cancelar),
                MDRaisedButton(text="OK", on_release=_ok),
            ],
        )
        self.dialog.open()


if __name__ == "__main__":
    GestorApp().run()
