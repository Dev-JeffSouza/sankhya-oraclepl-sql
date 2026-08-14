CREATE OR REPLACE PROCEDURE JS_STP_EXP_META_VEN_VDY (
    P_CODUSU NUMBER,        
    P_IDSESSAO VARCHAR2,   
    P_QTDLINHAS NUMBER,     
    P_MENSAGEM OUT VARCHAR2 
) AS 
    V_CODMETA       AD_TMTFATRTVEN.CODMETA%TYPE;
    V_CODVEND       AD_TMTFATRTVEN.CODVEND%TYPE;
    V_NRORESVEN     AD_TMTFATRTVEN.NRORESVEN%TYPE;
    V_NUCFGPFM      AD_TVDYCFGPFM.NUCFGPFM%TYPE;
    V_AFFECTED_ROWS NUMBER:= 0;
    V_PROXCOD       NUMBER;
    V_EXISTS        NUMBER;
    V_NOME          TGFVEN.APELIDO%TYPE;
    V_TITLE         VARCHAR(50):= '';
    V_TOPS          VARCHAR(4000):= '';
    V_CONFIR        VARCHAR(1);
    V_PARAM_DTINI   DATE;
    V_PARAM_DTFIN   DATE;
    V_DRTZ          VARCHAR2(4000);
    V_AVPERC        NUMBER;
BEGIN 
    V_PARAM_DTINI:= ACT_DTA_PARAM(P_IDSESSAO,'DTINI');
    V_PARAM_DTFIN:= ACT_DTA_PARAM(P_IDSESSAO,'DTFIN');
    V_TOPS:= REPLACE(GET_TSIPAR_TEXTO('TOPSVDYPFM'), ' ', '');
    V_AVPERC:= NVL(GET_TSIPAR_NUMERO('AVGERALPERC'), 2);
    V_DRTZ:= REPLACE(GET_TSIPAR_TEXTO('DRZVDYPFM'), ' ', '');

    IF V_PARAM_DTINI IS NULL OR V_PARAM_DTFIN IS NULL THEN
        P_MENSAGEM:= JS_FC_FORMATA_HTML5(
            P_TITULO => 'Intervalo de Referência',
            P_MOTIVO => 'Intervalo de datas não informado.',
            P_ACAO  => 'Informe a Data Inicial e Final para a referência da Meta nas Configurações de Performance do Vidya Force.'
        );
        RETURN;
    ELSIF V_PARAM_DTINI > V_PARAM_DTFIN THEN 
        P_MENSAGEM:= JS_FC_FORMATA_HTML5(
            P_TITULO => 'Sobreposição de Intervalos',
            P_MOTIVO => 'Data inicial superior a Data Final.',
            P_ACAO  => 'A Data inicial deverá ser inferior ou igual a Data Final.'
        );
        RETURN;
    END IF;

    IF V_DRTZ IS NULL THEN 
        P_MENSAGEM:= JS_FC_FORMATA_HTML5(
            P_TITULO => 'Diretrizes de Impacto',
            P_MOTIVO => 'Não foi possível localizar as diretrizes de Impacto para a meta..',
            P_ACAO  => 'Verifique se na Preferência (DRZVDYPFM) estão preenchidas as diretrizes para este procedimento. '
        );
        RETURN;
    END IF;

    FOR I IN 1..P_QTDLINHAS
    LOOP

        V_CODMETA:= ACT_INT_FIELD(P_IDSESSAO, I,'CODMETA');
        V_NRORESVEN:= ACT_INT_FIELD(P_IDSESSAO, I,'NRORESVEN');

        IF V_CODMETA IS NULL OR V_NRORESVEN IS NULL THEN 
            P_MENSAGEM:= JS_FC_FORMATA_HTML5(
                P_TITULO => 'Identificação da meta',
                P_MOTIVO => 'Código da meta não identificado no contexto atual.',
                P_ACAO   => 'Verifique se há vendedores cadastrados na meta atual.'
            ); 
            RETURN;
        END IF;

        BEGIN 
            SELECT MET.CODVEND, VEN.APELIDO
            INTO V_CODVEND, V_NOME
            FROM AD_TMTFATRTVEN MET
            JOIN TGFVEN VEN ON VEN.CODVEND = MET.CODVEND
            WHERE MET.CODMETA = V_CODMETA
                AND MET.NRORESVEN = V_NRORESVEN
            FETCH FIRST 1 ROWS ONLY;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN 
                V_CODVEND:= 0;
                V_NOME:= '<INDEFINIDO>';
        END;

        SELECT 
            COUNT(1),
            MAX(PFM.NUCFGPFM)
        INTO V_EXISTS, V_NUCFGPFM
        FROM AD_TVDYVEN VEN
        JOIN AD_TVDYCFGPFM PFM ON PFM.NUCFGPFM = VEN.NUCFGPFM
        WHERE PFM.CODMETA = V_CODMETA
            AND VEN.CODVEN = V_CODVEND;

        IF NVL(V_EXISTS, 0) > 0 THEN 

            V_CONFIR:= ACT_ESCOLHER_SIMNAO(
                P_TITULO => 'Meta já existente',
                P_TEXTO  => 'Vendedor(a) <b>' || TO_CHAR(V_CODVEND) || ' - ' || V_NOME || '</b>, '
                        || 'já possui uma meta de produtos cadastrada para este período/Meta.<br><br>'
                        || 'Deseja vinculá-lo novamente?',
                P_CHAVE => P_IDSESSAO,
                P_SEQUENCIA => I
            );

            IF V_CONFIR = 'N' THEN
                CONTINUE;
            END IF;

            --Deleção em cascata invertida (Filhos/Pai)
            DELETE FROM AD_TVDYDRTIPT WHERE NUCFGPFM = V_NUCFGPFM;
            DELETE FROM AD_TVDYPFMPRO WHERE NUCFGPFM = V_NUCFGPFM;
            DELETE FROM AD_TVDYPFMTOP WHERE NUCFGPFM = V_NUCFGPFM;
            DELETE FROM AD_TVDYVEN WHERE NUCFGPFM = V_NUCFGPFM;
            DELETE FROM AD_TVDYCFGPFM WHERE NUCFGPFM = V_NUCFGPFM;
        END IF;
        
        V_TITLE := 'META' || ' ' || SUBSTR(V_NOME, 1, INSTR(V_NOME || ' ', ' ') - 1) || ' - ' || RTRIM(TO_CHAR(V_PARAM_DTINI, 'MONTH'));
        STP_KEYGEN_TGFNUM ('AD_TVDYCFGPFM', 1,'AD_TVDYCFGPFM','NUCFGPFM', 0, V_PROXCOD);

        --Cabeçalho
        INSERT INTO AD_TVDYCFGPFM (NUCFGPFM, CODMETA, DTINI, DTFIM, TITULO)
        VALUES (V_PROXCOD, V_CODMETA, V_PARAM_DTINI, V_PARAM_DTFIN, V_TITLE);

        V_AFFECTED_ROWS:= SQL%ROWCOUNT;

        --Vendedores da meta (Configuração)
        INSERT INTO AD_TVDYVEN (NUCFGPFM, CODVEN)
        VALUES (V_PROXCOD, V_CODVEND);

        V_AFFECTED_ROWS:= V_AFFECTED_ROWS + SQL%ROWCOUNT;

        -- Tipos de Operações
        INSERT INTO AD_TVDYPFMTOP (NUCFGPFM, CODTIPOPER, TIPO)
        SELECT V_PROXCOD, COD_TOP, TIP_MOV
        FROM (
            SELECT 
                TOP.CODTIPOPER AS COD_TOP,
                TOP.TIPMOV  AS TIP_MOV,
                ROW_NUMBER() OVER(
                    PARTITION BY TOP.CODTIPOPER 
                    ORDER BY TOP.DHALTER DESC
                ) AS RN 
                FROM TGFTOP TOP
            WHERE TOP.CODTIPOPER IN (
                SELECT TO_NUMBER(REGEXP_SUBSTR(V_TOPS, '[^;]+', 1, LEVEL)) 
                FROM DUAL 
                CONNECT BY LEVEL <= REGEXP_COUNT(V_TOPS, ';') + 1
            )
        )
        WHERE RN = 1; --Garante que sempre trará a última versão da TOP

        V_AFFECTED_ROWS:= V_AFFECTED_ROWS + SQL%ROWCOUNT;

        -- Produtos da Meta/Vendedor/Performance
        INSERT INTO AD_TVDYPFMPRO (NUCFGPFM, SEQUENCIA, CODPROD, VALOR)
        SELECT V_PROXCOD, ROW_NUMBER()OVER(ORDER BY PRO.NROPROD) AS SEQ, PRO.CODPRODT, PRO.PXMETA
        FROM AD_TMTFATRTVENPRO PRO
        JOIN AD_TMTFATRTVEN VEN ON VEN.NRORESVEN = PRO.NRORESVEN
        WHERE VEN.CODMETA = V_CODMETA
            AND VEN.NRORESVEN = V_NRORESVEN
            AND VEN.CODVEND = V_CODVEND
            AND PRO.PXMETA > 0;

        V_AFFECTED_ROWS:= V_AFFECTED_ROWS + SQL%ROWCOUNT;

        --Diretrizes de Impacto
        INSERT INTO AD_TVDYDRTIPT (NUCFGPFM, NUDRTIPT, DIRETRIZ, META)
        SELECT 
            V_PROXCOD, 
            ROW_NUMBER()OVER(ORDER BY VEN.NRORESVEN) AS SEQ, Y.DRTZ, 
            CASE 
                WHEN Y.DRTZ IN (9) THEN ((VEN.PXMETA * V_AVPERC) / 100)  ---Depois ajustar pras outras opções
                ELSE VEN.PXMETA
            END AS META
        FROM AD_TMTFATRTVEN VEN
        CROSS JOIN (
            SELECT TO_NUMBER(REGEXP_SUBSTR(V_DRTZ, '[^;]+', 1, LEVEL))  AS DRTZ
            FROM DUAL 
            CONNECT BY LEVEL <= REGEXP_COUNT(V_DRTZ, ';') + 1
        ) Y
        WHERE VEN.CODMETA = V_CODMETA
            AND VEN.NRORESVEN = V_NRORESVEN
            AND VEN.CODVEND = V_CODVEND
            AND VEN.PXMETA > 0;

        V_AFFECTED_ROWS:= V_AFFECTED_ROWS + SQL%ROWCOUNT;
    END LOOP;

    IF NOT V_AFFECTED_ROWS > 0 THEN
        P_MENSAGEM:= JS_FC_CARD_ERR_HTML5('Configurações de Performance','Exportação não realizada.');
        RETURN;
    END IF;

    P_MENSAGEM := JS_FC_CARD_SUCESS_HTML5('Sucesso!','Metas exportadas para o Vidya Force - Configurações de Performance.');
EXCEPTION 
    WHEN OTHERS THEN 
        RAISE_APPLICATION_ERROR(-20001,'Erro ao exportar Metas/Produto para o Vidya Force.' || SQLERRM);
END;
