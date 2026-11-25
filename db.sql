CREATE TABLE jogadores (
    id_jogador SERIAL PRIMARY KEY,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha VARCHAR(50) NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo', 'banido'))
);

CREATE TABLE modalidades (
    id_modalidade SERIAL PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE,
    categoria VARCHAR(30) NOT NULL CHECK (categoria IN ('FPS', 'MOBA', 'Battle Royale', 'Esportes', 'Luta'))
);

CREATE TABLE torneios (
    id_torneio SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL UNIQUE,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL CHECK (data_fim >= data_inicio)
);

CREATE TABLE partidas (
    id_partida SERIAL PRIMARY KEY,
    titulo VARCHAR(120) NOT NULL,
    id_modalidade INT NOT NULL REFERENCES modalidades(id_modalidade),
    id_torneio INT NOT NULL REFERENCES torneios(id_torneio),
    id_jogador INT NOT NULL REFERENCES jogadores(id_jogador),
    data_partida TIMESTAMP NOT NULL,
    status VARCHAR(15) NOT NULL DEFAULT 'agendada' CHECK (status IN ('agendada', 'em_andamento', 'finalizada', 'cancelada')),
    data_criacao TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE inscricoes (
    id_inscricao SERIAL PRIMARY KEY,
    id_jogador INT NOT NULL REFERENCES jogadores(id_jogador),
    id_torneio INT NOT NULL REFERENCES torneios(id_torneio),
    data_inscricao TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_jogador, id_torneio)
);


CREATE TABLE historico_partidas (
    id_historico SERIAL PRIMARY KEY,
    id_partida INT NOT NULL REFERENCES partidas(id_partida) DEFERRABLE INITIALLY DEFERRED,
    acao VARCHAR(20) NOT NULL,
    descricao TEXT NOT NULL,
    data_log TIMESTAMP NOT NULL DEFAULT NOW()
);



CREATE OR REPLACE FUNCTION fn_buscar_jogadores(termo TEXT)
RETURNS TABLE (id_jogador INT, nickname VARCHAR(50), email VARCHAR(100), status VARCHAR(10))
AS $$
BEGIN
    RETURN QUERY
    SELECT j.id_jogador, j.nickname, j.email, j.status
    FROM jogadores j
    WHERE j.nickname ILIKE '%' || termo || '%'
       OR j.email ILIKE '%' || termo || '%';
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fn_validar_partida()
RETURNS TRIGGER AS $$
DECLARE
    status_jogador VARCHAR(10);
BEGIN
    SELECT status INTO status_jogador
    FROM jogadores
    WHERE id_jogador = NEW.id_jogador;

    IF status_jogador IS NULL OR status_jogador <> 'ativo' THEN
        RAISE EXCEPTION 'O jogador precisa existir e estar ativo para ter uma partida';
    END IF;

    NEW.data_criacao := NOW();

    INSERT INTO historico_partidas (id_partida, acao, descricao)
    VALUES (NEW.id_partida, 'INSERT', 'Partida criada: ' || NEW.titulo);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_partida
BEFORE INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_partida();


CREATE VIEW vw_painel_principal AS
SELECT j.nickname, p.titulo, m.categoria AS modalidade, p.data_partida, p.status
FROM partidas p
JOIN jogadores j ON j.id_jogador = p.id_jogador
JOIN modalidades m ON m.id_modalidade = p.id_modalidade;

CREATE VIEW vw_cronograma_partidas AS
SELECT p.titulo, p.status, p.data_partida,
       (p.data_partida::DATE - CURRENT_DATE) AS dias_restantes,
       j.nickname
FROM partidas p
JOIN jogadores j ON j.id_jogador = p.id_jogador
ORDER BY p.data_partida ASC;


INSERT INTO jogadores (nickname, email, senha, status) VALUES
    ('ShadowFox', 'shadowfox@email.com', 'senha123', 'ativo'),
    ('NeoBlaze', 'neoblaze@email.com', 'abc456', 'ativo'),
    ('IronWolf', 'ironwolf@email.com', 'lobo789', 'ativo'),
    ('GhostRider', 'ghost@email.com', 'ghost000', 'banido');

INSERT INTO modalidades (nome, categoria) VALUES
    ('Counter-Strike 2', 'FPS'),
    ('League of Legends', 'MOBA'),
    ('Free Fire', 'Battle Royale');

INSERT INTO torneios (nome, data_inicio, data_fim) VALUES
    ('Copa Verão 2026', CURRENT_DATE, CURRENT_DATE + 30),
    ('Liga Sul de E-Sports', CURRENT_DATE + 10, CURRENT_DATE + 60),
    ('Torneio Relâmpago', CURRENT_DATE + 5, CURRENT_DATE + 7);

INSERT INTO inscricoes (id_jogador, id_torneio) VALUES
    (1, 1),
    (2, 1),
    (3, 2);

INSERT INTO partidas (titulo, id_modalidade, id_torneio, id_jogador, data_partida) VALUES
    ('ShadowFox vs NeoBlaze - Semifinal', 1, 1, 1, NOW() + INTERVAL '3 days'),
    ('NeoBlaze vs IronWolf - Quartas', 2, 2, 2, NOW() + INTERVAL '1 day'),
    ('IronWolf vs ShadowFox - Final', 3, 3, 3, NOW() + INTERVAL '10 days');