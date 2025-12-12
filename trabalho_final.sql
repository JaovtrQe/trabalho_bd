DROP TABLE IF EXISTS diagnostico, fila_espera, triagem, ficha_paciente, medico, profissional, hospital, paciente CASCADE;

CREATE TABLE paciente (
    id_paciente SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    data_nascimento DATE,
    sexo CHAR(1),
    cpf VARCHAR(14) UNIQUE,
    rua TEXT,
    bairro TEXT,
    cidade TEXT,
    estado VARCHAR(2)
);

CREATE TABLE hospital (
    id_hospital SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    telefone VARCHAR(20),
    rua TEXT,
    bairro TEXT,
    cidade TEXT,
    estado VARCHAR(2)
);

CREATE TABLE profissional (
    id_profissional SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    cpf VARCHAR(14) UNIQUE,
    telefone VARCHAR(20),
    cargo TEXT
);

CREATE TABLE medico (
    id_medico SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    cpf VARCHAR(14) UNIQUE,
    telefone VARCHAR(20),
    especialidade TEXT
);

CREATE TABLE ficha_paciente (
    id_ficha SERIAL PRIMARY KEY,
    id_paciente INTEGER REFERENCES paciente(id_paciente),
    id_hospital INTEGER REFERENCES hospital(id_hospital),
    sintomas TEXT,
    nivel_atendimento VARCHAR(20),
    data_atendimento TIMESTAMP DEFAULT NOW()
);

CREATE TABLE triagem (
    id_triagem SERIAL PRIMARY KEY,
    id_profissional INTEGER REFERENCES profissional(id_profissional),
    id_paciente INTEGER REFERENCES paciente(id_paciente),
    nivel_urgencia INTEGER,
    horario TIMESTAMP DEFAULT NOW()
);

CREATE TABLE fila_espera (
    id_fila SERIAL PRIMARY KEY,
    id_paciente INTEGER REFERENCES paciente(id_paciente),
    nome_paciente TEXT,
    nivel_urgencia INTEGER,
    data_entrada TIMESTAMP DEFAULT NOW()
);

CREATE TABLE diagnostico (
    id_diagnostico SERIAL PRIMARY KEY,
    id_ficha INTEGER REFERENCES ficha_paciente(id_ficha),
    id_medico INTEGER REFERENCES medico(id_medico),
    descricao TEXT,
    data_diagnostico DATE DEFAULT CURRENT_DATE
);

-- POVOAMENTO

INSERT INTO paciente (nome, data_nascimento, sexo, cpf, rua, bairro, cidade, estado)
SELECT
    'Paciente ' || gs,
    CURRENT_DATE - (gs * INTERVAL '200 days'),
    CASE WHEN gs % 2 = 0 THEN 'M' ELSE 'F' END,
    LPAD(gs::text, 11, '0'),
    'Rua ' || gs,
    'Bairro ' || (gs % 10),
    'Crateús',
    'CE'
FROM generate_series(1,200) gs;

INSERT INTO hospital (nome, telefone, rua, bairro, cidade, estado)
SELECT
    'Hospital ' || gs,
    '+558899000' || gs,
    'Rua ' || gs,
    'Bairro ' || gs,
    'Crateús',
    'CE'
FROM generate_series(1,20) gs;

INSERT INTO profissional (nome, cpf, telefone, cargo)
SELECT
    'Profissional ' || gs,
    LPAD((10000 + gs)::text, 11, '0'),
    '+558899111' || gs,
    'Enfermeiro'
FROM generate_series(1,120) gs;

INSERT INTO medico (nome, cpf, telefone, especialidade)
SELECT
    'Médico ' || gs,
    LPAD((20000 + gs)::text, 11, '0'),
    '+558899222' || gs,
    'Clínico Geral'
FROM generate_series(1,140) gs;

INSERT INTO ficha_paciente (id_paciente, id_hospital, sintomas, nivel_atendimento, data_atendimento)
SELECT
    (gs % 200) + 1,
    (gs % 20) + 1,
    'Sintoma ' || gs,
    CASE WHEN gs % 3 = 0 THEN 'Alto' WHEN gs % 3 = 1 THEN 'Médio' ELSE 'Baixo' END,
    CURRENT_TIMESTAMP - (gs * INTERVAL '1 day')
FROM generate_series(1,300) gs;

INSERT INTO triagem (id_profissional, id_paciente, nivel_urgencia, horario)
SELECT
    (gs % 120) + 1,
    (gs % 200) + 1,
    (gs % 5) + 1,
    CURRENT_TIMESTAMP - (gs * INTERVAL '1 hour')
FROM generate_series(1,220) gs;

INSERT INTO fila_espera (id_paciente, nome_paciente, nivel_urgencia, data_entrada)
SELECT
    gs,
    'Paciente ' || gs,
    (gs % 5) + 1,
    CURRENT_TIMESTAMP - (gs * INTERVAL '1 hour')
FROM generate_series(1,160) gs;

INSERT INTO diagnostico (id_ficha, id_medico, descricao, data_diagnostico)
SELECT
    (gs % 300) + 1,
    (gs % 140) + 1,
    'Diagnóstico ' || gs,
    CURRENT_DATE - gs
FROM generate_series(1,320) gs;




------------------------------------------------------------
-- 3. CONSULTAS
------------------------------------------------------------

SELECT p.id_paciente, p.nome, COUNT(f.id_ficha) AS total_fichas
FROM paciente p
JOIN ficha_paciente f ON f.id_paciente = p.id_paciente
GROUP BY p.id_paciente, p.nome
HAVING COUNT(f.id_ficha) > 2
ORDER BY total_fichas DESC;

SELECT fe.id_fila, fe.nome_paciente, fe.nivel_urgencia,
       t.horario, pr.nome AS profissional
FROM fila_espera fe
LEFT JOIN triagem t ON t.id_paciente = fe.id_paciente
LEFT JOIN profissional pr ON pr.id_profissional = t.id_profissional
ORDER BY fe.data_entrada DESC;

SELECT m.especialidade, COUNT(d.id_diagnostico)
FROM diagnostico d
JOIN medico m ON m.id_medico = d.id_medico
GROUP BY m.especialidade
ORDER BY COUNT(d.id_diagnostico) DESC;

SELECT f.id_ficha, p.nome, f.data_atendimento
FROM ficha_paciente f
JOIN paciente p ON p.id_paciente = f.id_paciente
LEFT JOIN diagnostico d ON d.id_ficha = f.id_ficha
WHERE d.id_diagnostico IS NULL;

SELECT m.id_medico, m.nome, COUNT(d.id_diagnostico)
FROM medico m
JOIN diagnostico d ON d.id_medico = m.id_medico
GROUP BY m.id_medico, m.nome
HAVING COUNT(d.id_diagnostico) > 5;

SELECT p.id_paciente, p.nome
FROM paciente p
WHERE EXISTS (
    SELECT 1
    FROM ficha_paciente f
    JOIN diagnostico d ON d.id_ficha = f.id_ficha
    WHERE f.id_paciente = p.id_paciente
);

SELECT id_paciente, nome
FROM paciente
WHERE id_paciente IN (
    SELECT id_paciente
    FROM ficha_paciente
    WHERE id_hospital IN (
        SELECT id_hospital FROM hospital WHERE cidade = 'Fortaleza'
    )
);

SELECT p.id_paciente, p.nome, EXTRACT(YEAR FROM AGE(p.data_nascimento)) AS idade
FROM paciente p
WHERE EXTRACT(YEAR FROM AGE(p.data_nascimento)) >= ALL (
    SELECT EXTRACT(YEAR FROM AGE(data_nascimento)) FROM paciente
);

SELECT id_ficha, nivel_atendimento, data_atendimento
FROM ficha_paciente
WHERE nivel_atendimento = ANY (ARRAY['Alto','Médio'])
ORDER BY data_atendimento DESC;

SELECT h.id_hospital, h.nome, h.cidade, x.total_fichas
FROM hospital h
JOIN (
    SELECT id_hospital, COUNT(*) AS total_fichas
    FROM ficha_paciente
    GROUP BY id_hospital
) x ON x.id_hospital = h.id_hospital
ORDER BY total_fichas DESC
LIMIT 5;

