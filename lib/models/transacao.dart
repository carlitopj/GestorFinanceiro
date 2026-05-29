class Transacao {
  final int? id;
  final String usuario;
  final String descricao;
  final double valor;
  final String tipo;       // "Receita" ou "Despesa"
  final String categoria;
  final String mesRef;     // formato MM/AAAA

  Transacao({
    this.id,
    required this.usuario,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.categoria,
    required this.mesRef,
  });

  factory Transacao.fromMap(Map<String, dynamic> m) => Transacao(
    id:        m['id'] as int?,
    usuario:   m['usuario']   ?? '',
    descricao: m['descricao'] ?? '',
    valor:     (m['valor'] as num).toDouble(),
    tipo:      m['tipo']      ?? 'Despesa',
    categoria: m['categoria'] ?? 'Outros',
    mesRef:    m['mes_ref']   ?? '',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'usuario':   usuario,
    'descricao': descricao,
    'valor':     valor,
    'tipo':      tipo,
    'categoria': categoria,
    'mes_ref':   mesRef,
  };

  Transacao copyWith({
    int? id, String? usuario, String? descricao,
    double? valor, String? tipo, String? categoria, String? mesRef,
  }) => Transacao(
    id:        id        ?? this.id,
    usuario:   usuario   ?? this.usuario,
    descricao: descricao ?? this.descricao,
    valor:     valor     ?? this.valor,
    tipo:      tipo      ?? this.tipo,
    categoria: categoria ?? this.categoria,
    mesRef:    mesRef    ?? this.mesRef,
  );
}
