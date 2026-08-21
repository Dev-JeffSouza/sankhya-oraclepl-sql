CREATE OR REPLACE PROCEDURE JS_STP_IMPORT_MOV_VEN (
    P_CODUSU NUMBER,        
    P_IDSESSAO VARCHAR2,   
    P_QTDLINHAS NUMBER,     
    P_MENSAGEM OUT VARCHAR2 
) AS
    V_CODMETA           AD_TMTFAT.CODMETA%TYPE;
    V_NRORESVEN         AD_TMTFATRTVEN.NRORESVEN%TYPE; 
    V_CODEMP            TGFCAB.CODEMP%TYPE;  
    V_CODVEND           AD_TMTFATRTVEN.CODVEND%TYPE; 
    V_FATESTI           AD_TMTFATRTVEN.FATESTIVEN%TYPE;
    V_PTCVENCRESC       AD_TMTFATRTVEN.PTCVENCRESC%TYPE;
    V_NOME_DEST         TGFVEN.APELIDO%TYPE;
    V_NOME_ORIG_1       TGFVEN.APELIDO%TYPE;
    V_NOME_ORIG_2       TGFVEN.APELIDO%TYPE;
    V_NOME_CONCAT       TGFVEN.APELIDO%TYPE;
    V_AVVENPERC         AD_TMTFATRTVEN.AVVENPERC%TYPE;
    
    VP_CODVEND1         AD_TMTFATRTVEN.CODVEND%TYPE;
    V_FATVEND1          AD_TMTFATRTVEN.FATVEN%TYPE;
    VP_DTINI_V1         DATE;
    VP_DTFIN_V1         DATE;

    VP_CODVEND2         AD_TMTFATRTVEN.CODVEND%TYPE;
    V_FATVEND2          AD_TMTFATRTVEN.FATVEN%TYPE;
    VP_DTINI_V2         DATE;
    VP_DTFIN_V2         DATE;

    V_TOPS              VARCHAR2(4000);    
    FAT_TOTAL           AD_TMTFATRTVEN.FATVEN%TYPE;
    V_AFFECTED_ROWS     NUMBER:= 0;
    V_INFO              BOOLEAN;
    V_EXISTS            NUMBER:= 0;
BEGIN
    IF P_QTDLINHAS > 1 THEN
        P_MENSAGEM:= JS_FC_CARD_ERR_HTML5('Atenção', 'Selecione apenas um vendedor por vez.');
        RETURN;
    END IF;

    V_CODMETA:= ACT_INT_FIELD(P_IDSESSAO, 1,'CODMETA');
    V_NRORESVEN:= ACT_INT_FIELD(P_IDSESSAO, 1,'NRORESVEN');
    VP_CODVEND1:= ACT_INT_PARAM(P_IDSESSAO,'CODVEND1');
    VP_DTINI_V1:= ACT_DTA_PARAM(P_IDSESSAO,'DTINIVEN1');
    VP_DTFIN_V1:= ACT_DTA_PARAM(P_IDSESSAO,'DTFINVEN1');

    VP_CODVEND2:= ACT_INT_PARAM(P_IDSESSAO,'CODVEND2');
    VP_DTINI_V2:= ACT_DTA_PARAM(P_IDSESSAO,'DTINIVEN2');
    VP_DTFIN_V2:= ACT_DTA_PARAM(P_IDSESSAO,'DTFINVEN2');

    -- Validações iniciais
    IF V_CODMETA IS NULL THEN
        P_MENSAGEM:= JS_FC_FORMATA_HTML5 (
            P_TITULO => 'Erro ao identificar código da meta',
            P_MOTIVO => 'Não foi possível localizar o código da meta na aba de vendedores.',
            P_ACAO => 'Cadastre pelo menos um vendedor na meta, dessa forma será possível identifica-lo dentro da meta atual.'
        ); 
        RETURN;
    ELSIF COALESCE(VP_CODVEND1, VP_CODVEND2) IS NULL THEN
        P_MENSAGEM := JS_FC_FORMATA_HTML5(
            P_TITULO => 'Vendedor Não Informado',
            P_MOTIVO => 'Nenhum vendedor foi selecionado para realizar a consolidação das movimentações.',
            P_ACAO   => 'Preencha pelo menos um vendedor no formulário de Parâmetros antes de processar.'
        );
        RETURN;
    ELSIF VP_CODVEND1 IS NOT NULL AND (VP_DTINI_V1 IS NULL OR VP_DTFIN_V1 IS NULL) THEN
        P_MENSAGEM := JS_FC_FORMATA_HTML5(
            P_TITULO   => 'Intervalo de Datas Incompleto',
            P_MOTIVO   => 'Foi identificado que o período de movimentação está ausente ou incompleto.',
            P_ACAO     => 'Informe todo o intervalo de movimentação (Data Inicial e Final).',
            P_REGISTRO => 'Vendedor: ' || TO_CHAR(VP_CODVEND1)
        );
        RETURN;
    ELSIF VP_CODVEND2 IS NOT NULL AND (VP_DTINI_V2 IS NULL OR VP_DTFIN_V2 IS NULL) THEN
        P_MENSAGEM := JS_FC_FORMATA_HTML5(
            P_TITULO   => 'Intervalo de Datas Incompleto',
            P_MOTIVO   => 'Foi identificado que o período de movimentação está ausente ou incompleto.',
            P_ACAO     => 'Informe todo o intervalo de movimentação (Data Inicial e Final).',
            P_REGISTRO => 'Vendedor: ' || TO_CHAR(VP_CODVEND2)
        );
        RETURN;
    ELSIF VP_CODVEND1 = VP_CODVEND2 THEN
        P_MENSAGEM := JS_FC_FORMATA_HTML5(
            P_TITULO    => 'Vendedores duplicados',
            P_MOTIVO    => 'Foi identificado a duplicação de vendedores preenchido no formulário de parâmetros.',
            P_ACAO      => 'Informe códigos de vendedores diferentes, ou resultará em duplicação na importação da movimentação financeira.',
            P_REGISTRO  => 'Cód. Vendedores: ' || TO_CHAR(VP_CODVEND2) || ' e ' || TO_CHAR(VP_CODVEND2)
        );
        RETURN;
    END IF;

    BEGIN --Depois ajustar mais abaixo pra não trazer nomes de vendedores que não tenha movimentações
        SELECT 1
        INTO V_EXISTS
        FROM TGFCAB C
        WHERE C.TIPMOV = 'V'
            AND (
                    (C.CODVEND = VP_CODVEND1 AND C.DTMOV BETWEEN VP_DTINI_V1 AND VP_DTFIN_V1)
                OR 
                    (C.CODVEND = VP_CODVEND2 AND C.DTMOV BETWEEN VP_DTINI_V2 AND VP_DTFIN_V2)
            )
            AND ROWNUM = 1;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN 
            P_MENSAGEM:= JS_FC_CARD_ERR_HTML5('Importação não realizada.','Verique se há movimentação financeira no periodo informado para este(s) vendedor(es).');
            RETURN;
    END;

    BEGIN
        SELECT
            CODVEND, FATESTIVEN, PTCVENCRESC, AVVENPERC
        INTO V_CODVEND, V_FATESTI, V_PTCVENCRESC, V_AVVENPERC
        FROM AD_TMTFATRTVEN
        WHERE NRORESVEN = V_NRORESVEN
            AND CODMETA = V_CODMETA
        ORDER BY CODVEND
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_CODVEND:= 0; --Sem vendedor
    END;

    BEGIN
        SELECT
            MAX(CASE WHEN CODVEND = V_CODVEND THEN APELIDO END) AS NOME_DEST,
            MAX(CASE WHEN VP_CODVEND1 IS NOT NULL AND CODVEND = VP_CODVEND1 THEN SUBSTR(APELIDO, 1, INSTR(APELIDO || ' ', ' ') - 1) END) AS NOME_ORIG_1,
            MAX(CASE WHEN VP_CODVEND2 IS NOT NULL AND CODVEND = VP_CODVEND2 THEN SUBSTR(APELIDO, 1, INSTR(APELIDO || ' ', ' ') - 1) END) AS NOME_ORIG_2
        INTO V_NOME_DEST, V_NOME_ORIG_1, V_NOME_ORIG_2
        FROM TGFVEN 
        WHERE CODVEND = V_CODVEND
            OR (VP_CODVEND1 IS NOT NULL AND CODVEND = VP_CODVEND1)
            OR (VP_CODVEND2 IS NOT NULL AND CODVEND = VP_CODVEND2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_NOME_DEST:= 'Nome não localizado';
            V_NOME_ORIG_1:= 'Indefinido';
            V_NOME_ORIG_2:= 'Indefinido';
    END;    

    V_NOME_CONCAT:= CASE
                        WHEN VP_CODVEND1 IS NOT NULL AND VP_CODVEND2 IS NOT NULL THEN V_NOME_ORIG_1 || ' - ' || V_NOME_ORIG_2
                        WHEN VP_CODVEND1 IS NOT NULL AND VP_CODVEND2 IS NULL THEN V_NOME_ORIG_1
                        WHEN VP_CODVEND2 IS NOT NULL AND VP_CODVEND1 IS NULL THEN V_NOME_ORIG_2
                    END;

    V_INFO:= ACT_CONFIRMAR('Confirmação de Importação de Vendas','Deseja confirmar a transferência/importação das vendas para o vendedor destino **' 
                            || V_NOME_DEST || '**?', P_IDSESSAO, 1);

    V_TOPS:= ';' || REPLACE(GET_TSIPAR_TEXTO('TOPSCALCFAT'), ' ', '') || ';';
    V_CODEMP:= GET_TSIPAR_INTEIRO('DEFAULTEMP'); 

    -- Deleta antes de popular 
    DELETE FROM AD_TMTFATRTVENPCR WHERE NRORESVEN = V_NRORESVEN AND CODMETA = V_CODMETA;
    DELETE FROM AD_TMTFATRTVENPRO WHERE NRORESVEN = V_NRORESVEN AND CODMETA = V_CODMETA;
    DELETE FROM AD_TMTFATRTVEN WHERE NRORESVEN = V_NRORESVEN AND CODMETA = V_CODMETA; 

    V_FATVEND1:= NVL(JS_FC_CALC_FAT(P_DTINI => VP_DTINI_V1, P_DTFIN => VP_DTFIN_V1, P_CODVEND => VP_CODVEND1, P_CODEMP => V_CODEMP), 0);
    V_FATVEND2:= NVL(JS_FC_CALC_FAT(P_DTINI => VP_DTINI_V2, P_DTFIN => VP_DTFIN_V2, P_CODVEND => VP_CODVEND2, P_CODEMP => V_CODEMP), 0);
    FAT_TOTAL:= NVL(V_FATVEND1 + V_FATVEND2, 0);

    --Vendedor
    V_NRORESVEN:= JS_SEQ.NEXTVAL;
    INSERT INTO AD_TMTFATRTVEN (CODMETA, NRORESVEN, CODVEND, FATVEN, PTCVEN, AVVENPERC, PTCVENCRESC, PXMETA, FATESTIVEN, AVVEN, VPERCVEN, MOVIMPORTVEN, VENORIGMOV)
    VALUES (V_CODMETA, V_NRORESVEN, V_CODVEND, FAT_TOTAL, 0, 2, 0, 0, 0, 0, 0, 'S', V_NOME_CONCAT);
    
    -- Parceiros do Vendedor (Resultados agrupados)
    INSERT INTO AD_TMTFATRTVENPCR (CODMETA, NRORESVEN, NRORESPCR, CODPARC, FATPCR, PTCPCR, AVPCRPERC, PTCPCRCRESC, PXMETA, FATESTIPCR, AVPCR, VPERCPCR, MOVIMPORTVEN)
    SELECT V_CODMETA, V_NRORESVEN, JS_SEQ.NEXTVAL, Y.CODPARC, Y.FAT_PCR, 0, 2, 0, 0, 0, 0, 0,'S'
    FROM (
        SELECT 
            C.CODPARC,
            NVL(SUM(CASE 
                        WHEN C.TIPMOV = 'V' THEN C.VLRNOTA 
                        WHEN C.TIPMOV = 'D' THEN -C.VLRNOTA 
                        ELSE 0 
                    END), 0) AS FAT_PCR
        FROM TGFCAB C
        WHERE V_TOPS LIKE '%;' || TO_CHAR(C.CODTIPOPER) || ';%'
            AND C.TIPMOV IN ('V','D') 
            AND C.STATUSNOTA = 'L'
            AND C.CODEMP = V_CODEMP
            AND (
                    (C.CODVEND = VP_CODVEND1 AND C.DTMOV BETWEEN VP_DTINI_V1 AND VP_DTFIN_V1) 
                OR 
                    (C.CODVEND = VP_CODVEND2 AND C.DTMOV BETWEEN VP_DTINI_V2 AND VP_DTFIN_V2) 
            )
        GROUP BY 
            C.CODPARC
        ORDER BY 
            C.CODPARC ASC
    ) Y;

    V_AFFECTED_ROWS:= V_AFFECTED_ROWS + SQL%ROWCOUNT;
    -- Produtos do Vendedor (Resultados agrupados)
    INSERT INTO AD_TMTFATRTVENPRO (CODMETA, NRORESVEN, NROPROD, CODPRODT, FATVENPRO, AVVENPROPERC, PTCVENPROCRESC, FATESTIVENPRO, PTCVENPRO, AVVENPRO, PXMETA, VPERCVENPRO, MOVIMPORTVEN)
    SELECT V_CODMETA, V_NRORESVEN, JS_SEQ.NEXTVAL, Y.CODPROD, Y.FAT_PROD, 2, 0, 0, 0, 0, 0, 0,'S'
    FROM (
         SELECT 
            I.CODPROD,
            NVL(SUM(
                CASE --Rateio de descontos distribuidos proporcionalmente 
                    WHEN C.TIPMOV = 'V' THEN  
                        (I.VLRTOT - NVL(I.VLRDESC, 0) - 
                        ((NVL(C.VLRDESCTOT, 0) + NVL(C.VLRDESCPARCERIA, 0)) * 
                        (I.VLRTOT / NULLIF(C.VLRNOTA, 0))))
                    ELSE 
                        -(I.VLRTOT - NVL(I.VLRDESC, 0) - 
                        ((NVL(C.VLRDESCTOT, 0) + NVL(C.VLRDESCPARCERIA, 0)) * 
                        (I.VLRTOT / NULLIF(C.VLRNOTA, 0))))
                END
            ), 0) AS FAT_PROD
        FROM TGFITE I
        JOIN TGFCAB C ON C.NUNOTA = I.NUNOTA
        WHERE V_TOPS LIKE '%;' || TO_CHAR(C.CODTIPOPER) || ';%'
            AND C.TIPMOV IN ('V','D') 
            AND C.STATUSNOTA = 'L'
            AND C.CODEMP = V_CODEMP
            AND (
                    (C.CODVEND = VP_CODVEND1 AND C.DTMOV BETWEEN VP_DTINI_V1 AND VP_DTFIN_V1) 
                OR 
                    (C.CODVEND = VP_CODVEND2 AND C.DTMOV BETWEEN VP_DTINI_V2 AND VP_DTFIN_V2) 
            )
        GROUP BY 
            I.CODPROD
        ORDER BY    
            I.CODPROD ASC
    ) Y;

    V_AFFECTED_ROWS:= V_AFFECTED_ROWS + SQL%ROWCOUNT;

    IF NOT V_AFFECTED_ROWS > 0 THEN
        P_MENSAGEM:= JS_FC_CARD_ERR_HTML5('Importação não realizada.','Nenhuma movimentação foi processada.');
        RETURN;
    END IF;

    P_MENSAGEM:= JS_FC_CARD_SUCESS_HTML5('Sucesso!','Importação e consolidação de movimentações realizadas para o vendedor: <b>' || TO_CHAR(V_CODVEND) || ' - ' || V_NOME_DEST ||'</b>');
    PKG_METAS_FATURAMENTO.RESET_PKG;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004, '<b>Erro:</b> Não foi possível realizar a importação das movimentações.' || SQLERRM);
END;
