import os
import shutil
from datetime import datetime

from kivy.lang import Builder
from kivy.metrics import dp
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.widget import Widget
from kivy.graphics import Color, Rectangle, Line, Ellipse
from kivy.core.window import Window
from kivy.utils import platform, get_color_from_hex

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


MESES = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
         "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]

MES_ABREV = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
              "Jul", "Ago", "Set", "Out", "Nov", "Dez"]

CORES_CATEGORIA = [
    "#27ae60", "#e74c3c", "#3498db", "#f39c12", "#9b59b6",
    "#1abc9c", "#e67e22", "#2c3e50", "#16a085", "#d35400",
    "#8e44ad", "#2980b9",
]


def formatar_real(valor):
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


# ---------------------------------------------------------------------------
# Widgets de gráfico desenhados em Canvas (sem dependências externas)
# ---------------------------------------------------------------------------
class GraficoBarrasWidget(Widget):
    """Gráfico de barras agrupadas: Receitas x Despesas por mês."""

    def __init__(self, labels, receitas, despesas, **kwargs):
        super().__init__(**kwargs)
        self.labels = labels
        self.receitas = receitas
        self.despesas = despesas
        self.bind(pos=self.redraw, size=self.redraw)

    def redraw(self, *args):
        self.canvas.clear()
        if not self.labels:
            return

        with self.canvas:
            pad_left = dp(60)
            pad_bottom = dp(50)
            pad_top = dp(20)
            pad_right = dp(20)

            largura = self.width - pad_left - pad_right
            altura = self.height - pad_bottom - pad_top
            if largura <= 0 or altura <= 0:
                return

            valor_max = max(max(self.receitas, default=0), max(self.despesas, default=0), 1)

            n = len(self.labels)
            grupo_w = largura / n

            # Eixos
            Color(0.6, 0.6, 0.6, 1)
            Line(points=[self.x + pad_left, self.y + pad_bottom,
                          self.x + pad_left, self.y + pad_bottom + altura], width=1)
            Line(points=[self.x + pad_left, self.y + pad_bottom,
                          self.x + pad_left + largura, self.y + pad_bottom], width=1)

            for i, mes in enumerate(self.labels):
                base_x = self.x + pad_left + i * grupo_w
                bar_w = grupo_w * 0.32

                rec = self.receitas[i]
                desp = self.despesas[i]

                h_rec = (rec / valor_max) * altura
                h_desp = (desp / valor_max) * altura

                # Receita (verde)
                Color(*get_color_from_hex("#27ae60"))
                Rectangle(pos=(base_x + grupo_w * 0.12, self.y + pad_bottom),
                          size=(bar_w, h_rec))

                # Despesa (vermelho)
                Color(*get_color_from_hex("#e74c3c"))
                Rectangle(pos=(base_x + grupo_w * 0.56, self.y + pad_bottom),
                          size=(bar_w, h_desp))

        # Labels (mês embaixo, valores em cima das barras)
        self.clear_widgets()
        for i, mes in enumerate(self.labels):
            base_x = self.x + pad_left + i * grupo_w
            lbl_mes = MDLabel(
                text=mes, halign="center", font_style="Caption",
                pos=(base_x, self.y),
                size=(grupo_w, dp(20)),
                size_hint=(None, None),
            )
            self.add_widget(lbl_mes)

            rec = self.receitas[i]
            desp = self.despesas[i]
            h_rec = (rec / valor_max) * altura if valor_max else 0
            h_desp = (desp / valor_max) * altura if valor_max else 0

            if rec > 0:
                lbl_r = MDLabel(
                    text=f"{rec:,.0f}".replace(",", "."),
                    halign="center", font_style="Caption",
                    pos=(base_x + grupo_w * 0.12 - dp(10), self.y + pad_bottom + h_rec),
                    size=(bar_w + dp(20), dp(16)),
                    size_hint=(None, None),
                    theme_text_color="Custom",
                    text_color=get_color_from_hex("#27ae60"),
                )
                self.add_widget(lbl_r)

            if desp > 0:
                lbl_d = MDLabel(
                    text=f"{desp:,.0f}".replace(",", "."),
                    halign="center", font_style="Caption",
                    pos=(base_x + grupo_w * 0.56 - dp(10), self.y + pad_bottom + h_desp),
                    size=(bar_w + dp(20), dp(16)),
                    size_hint=(None, None),
                    theme_text_color="Custom",
                    text_color=get_color_from_hex("#e74c3c"),
                )
                self.add_widget(lbl_d)


class GraficoPizzaWidget(Widget):
    """Gráfico de pizza simples: gastos por categoria."""

    def __init__(self, dados, **kwargs):
        # dados: lista de tuplas (categoria, valor)
        super().__init__(**kwargs)
        self.dados = dados
        self.bind(pos=self.redraw, size=self.redraw)

    def redraw(self, *args):
        self.canvas.clear()
        self.clear_widgets()
        if not self.dados:
            return

        total = sum(v for _, v in self.dados) or 1

        diametro = min(self.width, self.height) * 0.7
        cx = self.x + self.width * 0.35
        cy = self.y + self.height * 0.5

        with self.canvas:
            angulo_inicial = 0
            for i, (cat, valor) in enumerate(self.dados):
                fatia = (valor / total) * 360
                cor = CORES_CATEGORIA[i % len(CORES_CATEGORIA)]
                Color(*get_color_from_hex(cor))
                Ellipse(
                    pos=(cx - diametro / 2, cy - diametro / 2),
                    size=(diametro, diametro),
                    angle_start=angulo_inicial,
                    angle_end=angulo_inicial + fatia,
                )
                angulo_inicial += fatia

        # Legenda
        legend_x = self.x + self.width * 0.72
        legend_y = self.y + self.height - dp(20)
        for i, (cat, valor) in enumerate(self.dados):
            cor = CORES_CATEGORIA[i % len(CORES_CATEGORIA)]
            pct = (valor / total) * 100

            with self.canvas:
                Color(*get_color_from_hex(cor))
                Rectangle(pos=(legend_x, legend_y - i * dp(24)), size=(dp(14), dp(14)))

            lbl = MDLabel(
                text=f"{cat}: {pct:.1f}%",
                font_style="Caption",
                pos=(legend_x + dp(20), legend_y - i * dp(24) - dp(4)),
                size=(dp(160), dp(20)),
                size_hint=(None, None),
            )
            self.add_widget(lbl)


class GraficoLinhaWidget(Widget):
    """Gráfico de linha: evolução anual de receitas x despesas."""

    def __init__(self, labels, receitas, despesas, **kwargs):
        super().__init__(**kwargs)
        self.labels = labels
        self.receitas = receitas
        self.despesas = despesas
        self.bind(pos=self.redraw, size=self.redraw)

    def redraw(self, *args):
        self.canvas.clear()
        self.clear_widgets()
        if not self.labels:
            return

        pad_left = dp(60)
        pad_bottom = dp(40)
        pad_top = dp(20)
        pad_right = dp(20)

        largura = self.width - pad_left - pad_right
        altura = self.height - pad_bottom - pad_top
        if largura <= 0 or altura <= 0:
            return

        valor_max = max(max(self.receitas, default=0), max(self.despesas, default=0), 1)
        n = len(self.labels)
        passo_x = largura / max(n - 1, 1)

        with self.canvas:
            Color(0.6, 0.6, 0.6, 1)
            Line(points=[self.x + pad_left, self.y + pad_bottom,
                          self.x + pad_left, self.y + pad_bottom + altura], width=1)
            Line(points=[self.x + pad_left, self.y + pad_bottom,
                          self.x + pad_left + largura, self.y + pad_bottom], width=1)

            def desenhar_linha(valores, cor_hex):
                Color(*get_color_from_hex(cor_hex))
                pontos = []
                for i, v in enumerate(valores):
                    px = self.x + pad_left + i * passo_x
                    py = self.y + pad_bottom + (v / valor_max) * altura
                    pontos.extend([px, py])
                if len(pontos) >= 4:
                    Line(points=pontos, width=dp(2))
                for i in range(0, len(pontos), 2):
                    Ellipse(pos=(pontos[i] - dp(3), pontos[i + 1] - dp(3)), size=(dp(6), dp(6)))

            desenhar_linha(self.receitas, "#27ae60")
            desenhar_linha(self.despesas, "#e74c3c")

        # Labels do eixo X (meses)
        for i, mes in enumerate(self.labels):
            px = self.x + pad_left + i * passo_x
            lbl = MDLabel(
                text=mes, halign="center", font_style="Caption",
                pos=(px - dp(15), self.y),
                size=(dp(30), dp(20)),
                size_hint=(None, None),
            )
            self.add_widget(lbl)


# ---------------------------------------------------------------------------
# Funções de busca/preparação de dados para os gráficos
# ---------------------------------------------------------------------------
def dados_grafico_barras(usuario):
    dados = db.buscar_historico_grafico(usuario)
    if not dados:
        return None
    resumo = {}
    for v, t, m in dados:
        if m not in resumo:
            resumo[m] = {"Receita": 0.0, "Despesa": 0.0}
        resumo[m][t] += float(v)
    meses_ord = sorted(resumo.keys(), key=lambda x: datetime.strptime(x, "%m/%Y"))
    labels = []
    for m in meses_ord:
        mes_num = int(m.split("/")[0])
        labels.append(MES_ABREV[mes_num - 1])
    recs = [resumo[m]["Receita"] for m in meses_ord]
    desps = [resumo[m]["Despesa"] for m in meses_ord]
    return labels, recs, desps


def dados_grafico_pizza(usuario, mes_ref):
    dados = db.buscar_transacoes_por_mes(usuario, mes_ref)
    gastos = {}
    for item in dados:
        if item[3] == "Despesa":
            cat = item[4] if item[4] else "Outros"
            gastos[cat] = gastos.get(cat, 0) + float(item[2])
    if not gastos:
        return None
    return sorted(gastos.items(), key=lambda x: x[1], reverse=True)


def dados_grafico_anual(usuario, ano):
    dados = db.buscar_dados_anuais(usuario, ano)
    if not dados:
        return None
    resumo = {f"{i:02d}/{ano}": {"Receita": 0.0, "Despesa": 0.0} for i in range(1, 13)}
    for v, t, m in dados:
        if m in resumo:
            resumo[m][t] += float(v)
    meses = sorted(resumo.keys())
    labels = [MES_ABREV[int(m.split("/")[0]) - 1] for m in meses]
    recs = [resumo[m]["Receita"] for m in meses]
    desps = [resumo[m]["Despesa"] for m in meses]
    return labels, recs, desps


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
            id: topbar_grafico
            title: "Gráfico"
            left_action_items: [["arrow-left", lambda x: app.voltar_main()]]

        BoxLayout:
            id: container_grafico
            orientation: "vertical"
            padding: dp(8)
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
        screen = self.root_widget.get_screen("grafico")
        container = screen.ids.container_grafico
        container.clear_widgets()

        if tipo == "barras":
            screen.ids.topbar_grafico.title = "Receitas x Despesas (Mensal)"
            dados = dados_grafico_barras(self.usuario_atual)
            if not dados:
                self.mostrar_aviso("Sem dados suficientes para gerar o gráfico.")
                return
            labels, recs, desps = dados
            container.add_widget(GraficoBarrasWidget(labels, recs, desps))

        elif tipo == "pizza":
            screen.ids.topbar_grafico.title = f"Gastos por Categoria - {self.get_mes_referencia()}"
            dados = dados_grafico_pizza(self.usuario_atual, self.get_mes_referencia())
            if not dados:
                self.mostrar_aviso("Sem dados suficientes para gerar o gráfico.")
                return
            container.add_widget(GraficoPizzaWidget(dados))

        elif tipo == "anual":
            ano = datetime.now().year
            screen.ids.topbar_grafico.title = f"Evolução Anual {ano}"
            dados = dados_grafico_anual(self.usuario_atual, ano)
            if not dados:
                self.mostrar_aviso("Sem dados suficientes para gerar o gráfico.")
                return
            labels, recs, desps = dados
            container.add_widget(GraficoLinhaWidget(labels, recs, desps))

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
