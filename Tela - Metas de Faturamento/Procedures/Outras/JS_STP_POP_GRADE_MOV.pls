CREATE OR REPLACE PROCEDURE JS_STP_POP_GRADE_MOV (
    P_CODUSU NUMBER,        
    P_IDSESSAO VARCHAR2,   
    P_QTDLINHAS NUMBER,     
    P_MENSAGEM OUT VARCHAR2 
) AS
    V_PROXNRORESVEN     AD_TMTFATRTVEN.NRORESVEN%TYPE;
    V_PARAM_CODEMP      AD_TMTFAT.CODEMP%TYPE;
    V_CODEMP            AD_TMTFAT.CODEMP%TYPE;
    V_CODEMPMETA        AD_TMTFAT.CODEMP%TYPE;
    V_FIELD_CODMETA     AD_TMTFAT.CODMETA%TYPE;

    V_DTINI             AD_TMTFAT.DTINI%TYPE;
    V_DTFIN             AD_TMTFAT.DTFIN%TYPE;
    V_PERCAV            NUMBER := 2;
    V_CRESC             NUMBER := 0;
    V_FATEST            NUMBER := 0;
BEGIN
    
    IF P_QTDLINHAS > 1 THEN
        P_MENSAGEM:= '<b>É permitido popular por movimentação uma meta por vez. Linhas selecionadas:</b> ' || TO_CHAR(P_QTDLINHAS);
        RETURN;
    END IF;

    V_PARAM_CODEMP:= ACT_INT_PARAM(P_IDSESSAO,'CODEMP');
    V_FIELD_CODMETA := ACT_INT_FIELD(P_IDSESSAO, 1, 'CODMETA');

    IF V_FIELD_CODMETA IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001,'Erro: <b>A meta selecionada não foi identificada. Certifique-se de que o registro está salvo antes de popular.</b>');
    ELSIF V_PARAM_CODEMP IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Preencha o código da Empresa.</b>');
    END IF;

    --Bloco para buScar dados na mestre
    BEGIN
        SELECT CODEMP, DTINI, DTFIN 
        INTO V_CODEMPMETA, V_DTINI, V_DTFIN 
        FROM AD_TMTFAT 
        WHERE CODMETA = V_FIELD_CODMETA
            AND ROWNUM = 1;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN 
            V_CODEMPMETA:= V_PARAM_CODEMP;
            V_DTINI:= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');
            V_DTFIN:= TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));
    END;

    --Verifica se existe ocorrência de registro da empresa
    SELECT COUNT(*) INTO V_CODEMP FROM TSIEMP WHERE CODEMP = V_PARAM_CODEMP;

    --Validações da empresa
    IF V_CODEMP = 0 THEN
        RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Empresa ' || TO_CHAR(V_PARAM_CODEMP) || ' não existe ou não foi cadastrada.</b>');
    ELSIF V_CODEMPMETA <> V_PARAM_CODEMP THEN
        RAISE_APPLICATION_ERROR(-20001,'Erro: <b>A Empresa informada diverge da cadastrada na meta.</b>');
    END IF;

    -- Deleção 
    DELETE FROM AD_TMTFATRTVENPCR WHERE CODMETA = V_FIELD_CODMETA;
    DELETE FROM AD_TMTFATRTVENPRO WHERE CODMETA = V_FIELD_CODMETA;
    DELETE FROM AD_TMTFATRTVEN WHERE CODMETA = V_FIELD_CODMETA;
    DELETE FROM AD_TMTFATRTPRO WHERE CODMETA = V_FIELD_CODMETA;

                                    --<<    Bloco de Explosão de itens nas grades  >>--
                                    
    --Polulando a grade de produtos (Somente produtos com movimentação de vendas no período)
    FOR PRO IN(
        SELECT
            I.CODPROD AS COD_PROD
        FROM TGFITE I
        JOIN TGFCAB C ON C.NUNOTA = I.NUNOTA
        JOIN TGFPRO P ON P.CODPROD = I.CODPROD
        WHERE C.DTMOV BETWEEN V_DTINI AND V_DTFIN
            AND C.CODTIPOPER IN (1101,1201)
            AND C.TIPMOV IN ('V','D')
            AND C.STATUSNOTA = 'L'
            AND C.CODEMP = V_CODEMPMETA
            AND P.CODGRUPOPROD IN (
                        10100000, 10200100, 10200200,
                        10200300, 10400000, 10300000,110100000,110200000)
        GROUP BY 
            I.CODPROD
        ORDER BY
            I.CODPROD ASC)
    LOOP
        INSERT INTO AD_TMTFATRTPRO (CODMETA,NRORESPRO, CODPROD,AVPRODPERC,PTCPRODCRESC, FATESTIPRO)
        VALUES (V_FIELD_CODMETA,JS_SEQ.NEXTVAL, PRO.COD_PROD, V_PERCAV, V_CRESC, V_FATEST);
    END LOOP;

    --Polulando a grade de vendedores que possuem movimentações no período (Com loops aninhados, por conta da relação)
    FOR VEN IN (
        SELECT 
            C.CODVEND AS COD_VEN
        FROM TGFCAB C
        WHERE C.DTMOV BETWEEN V_DTINI AND V_DTFIN
            AND C.CODTIPOPER IN (1101,1201)
            AND C.TIPMOV IN ('V','D')
            AND C.STATUSNOTA = 'L'
            AND C.CODEMP = V_CODEMPMETA
        GROUP BY
            C.CODVEND
        ORDER BY 
            C.CODVEND ASC)
    LOOP
        V_PROXNRORESVEN := JS_SEQ.NEXTVAL; --(JS_SEQ - Sequence Personalizado)

        INSERT INTO AD_TMTFATRTVEN (CODMETA,NRORESVEN,CODVEND,AVVENPERC,PTCVENCRESC, FATESTIVEN)
        VALUES (V_FIELD_CODMETA, V_PROXNRORESVEN, VEN.COD_VEN, V_PERCAV, V_CRESC, V_FATEST);

            --Populando a grade de Parceiros com movimentação no período/Vendedor
            FOR PARC IN (
                SELECT 
                    C.CODPARC AS COD_PARC_VEN
                FROM TGFCAB C
                WHERE C.DTMOV BETWEEN V_DTINI AND V_DTFIN
                    AND C.CODTIPOPER IN (1101,1201)
                    AND C.TIPMOV IN ('V','D')
                    AND C.STATUSNOTA = 'L'
                    AND C.CODEMP = V_CODEMPMETA
                    AND C.CODVEND = VEN.COD_VEN
                GROUP BY
                    C.CODPARC
                ORDER BY 
                    C.CODPARC ASC)
            LOOP
                INSERT INTO AD_TMTFATRTVENPCR (CODMETA,NRORESVEN, NRORESPCR,CODPARC,AVPCRPERC, PTCPCRCRESC, FATESTIPCR)
                VALUES (V_FIELD_CODMETA,V_PROXNRORESVEN,JS_SEQ.NEXTVAL,PARC.COD_PARC_VEN,V_PERCAV, V_CRESC, V_FATEST);
            END LOOP;    

            --Populando a grande de produtos/vendedor com movimentações no período
            FOR PVEN IN (
                SELECT 
                    I.CODPROD AS COD_PROD_VEN
                FROM TGFITE I
                JOIN TGFCAB C ON C.NUNOTA = I.NUNOTA
                WHERE C.DTMOV BETWEEN V_DTINI AND V_DTFIN
                    AND C.CODTIPOPER IN (1101,1201)
                    AND C.TIPMOV IN ('V','D')
                    AND C.STATUSNOTA = 'L'
                    AND C.CODEMP = V_CODEMPMETA
                    AND C.CODVEND = VEN.COD_VEN
                GROUP BY
                    I.CODPROD
                ORDER BY 
                    I.CODPROD ASC)
            LOOP
                INSERT INTO AD_TMTFATRTVENPRO (CODMETA, NRORESVEN, NROPROD, CODPRODT,AVVENPROPERC, PTCVENPROCRESC, FATESTIVENPRO)
                VALUES (V_FIELD_CODMETA, V_PROXNRORESVEN, JS_SEQ.NEXTVAL, PVEN.COD_PROD_VEN,V_PERCAV, V_CRESC, V_FATEST);
            END LOOP;
    END LOOP;
                                    --<<    Bloco de calculos (Chamadas em cascata) >>--
    
    JS_STP_CALC_RES_PRO(P_CODMETA => V_FIELD_CODMETA, P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODEMP => V_CODEMPMETA);
    JS_STP_CALC_META_VEN(P_CODMETA => V_FIELD_CODMETA, P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODEMP => V_CODEMPMETA);
    JS_STP_CALC_RES_VEN_PCR(P_CODMETA => V_FIELD_CODMETA, P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODEMP => V_CODEMPMETA);
    JS_STP_CALC_RES_VEN_PRO(P_CODMETA => V_FIELD_CODMETA, P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODEMP => V_CODEMPMETA);

    --Registra usuário,data e hora de alteração
    UPDATE AD_TMTFAT SET DHALTER = SYSDATE,CODUSU = P_CODUSU WHERE CODMETA = V_FIELD_CODMETA;

    P_MENSAGEM := '<b>Sucesso! Grade de Metas gerada com base na movimentação histórica de vendas!</b>';

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001,'<b>Erro ao popular grades de metas:</b> ' || SQLERRM);
END;


