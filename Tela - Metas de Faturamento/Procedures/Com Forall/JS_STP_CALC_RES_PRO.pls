CREATE OR REPLACE PROCEDURE JS_STP_CALC_RES_PRO (
    P_TIPOEVENTO INT DEFAULT NULL,
    P_IDSESSAO VARCHAR2 DEFAULT NULL,
    P_CODUSU INT DEFAULT NULL,
    --Parametros de entrada disparados por Trigger e STP de explosão de registros (Padrão nulo, pra não dá erro em eventos)
    P_DTINI           IN DATE DEFAULT NULL,      
    P_DTFIN           IN DATE DEFAULT NULL,  
    P_CODMETA         IN INT DEFAULT NULL,
    P_FATGERAL        IN NUMBER DEFAULT NULL, 
    P_FATGERALMETA    IN NUMBER DEFAULT NULL,
    P_CODEMP          IN INT DEFAULT NULL
) AS 
    BEFORE_INSERT    INT:= 0;
    BEFORE_UPDATE    INT:= 4;

    V_CODMETA        AD_TMTFATRTPRO.CODMETA%TYPE;    
    V_CODPROD        AD_TMTFATRTPRO.CODPROD%TYPE;  

    V_DTINI          AD_TMTFAT.DTINI%TYPE;           
    V_DTFIN          AD_TMTFAT.DTFIN%TYPE;           
    V_FATGERALANT    AD_TMTFAT.FATGERAL%TYPE;       
    V_FATGERALMETA   AD_TMTFAT.FATGERALMETA%TYPE;  
    V_CODEMP         AD_TMTFAT.CODEMP%TYPE;

    V_FATPROD        AD_TMTFATRTPRO.FATPROD%TYPE;      
    V_PTCPROD        AD_TMTFATRTPRO.PTCPROD%TYPE;     
    V_AVPROD         AD_TMTFATRTPRO.AVPROD%TYPE;       
    V_AVPRODPERC     AD_TMTFATRTPRO.AVPRODPERC%TYPE;   
    V_PTCPRODCRESC   AD_TMTFATRTPRO.PTCPRODCRESC%TYPE; 
    V_PXMETA         AD_TMTFATRTPRO.PXMETA%TYPE; 
    V_VARPERC        AD_TMTFATRTPRO.VPERCPROD%TYPE;
    V_FATEST         AD_TMTFATRTPRO.FATESTIPRO%TYPE;
    V_QTDNEG         AD_TMTFATRTPRO.QTDNEG%TYPE;
    V_TCKAVG         AD_TMTFATRTPRO.TCKAVG%TYPE;
    V_METAITE        AD_TMTFATRTPRO.QTDNEGMETA%TYPE;

    V_SUMFAT         NUMBER;
    CSDEC            INT;
BEGIN
    CSDEC:= NVL(GET_TSIPAR_INTEIRO('CSDEC'), 2);
    --Bloco de Cálculo manual
    IF P_TIPOEVENTO = BEFORE_INSERT OR P_TIPOEVENTO = BEFORE_UPDATE THEN

        V_CODMETA := EVP_GET_CAMPO_INT(P_IDSESSAO,'CODMETA');
        V_CODPROD:= EVP_GET_CAMPO_INT(P_IDSESSAO,'CODPROD');
        V_AVPRODPERC:= EVP_GET_CAMPO_DEC(P_IDSESSAO,'AVPRODPERC');
        V_PTCPRODCRESC:= EVP_GET_CAMPO_DEC(P_IDSESSAO,'PTCPRODCRESC');
        V_FATEST:= EVP_GET_CAMPO_DEC(P_IDSESSAO,'FATESTIPRO');

        IF V_CODMETA IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Não foi possível identificar o código da Meta.</b>');
        ELSIF V_CODPROD IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Preencha o código do produto.</b>');
        END IF;

        --Busca os dados da tabela Mestre
        BEGIN
            SELECT DTINI,DTFIN,FATGERALMETA,FATGERAL,CODEMP
            INTO V_DTINI, V_DTFIN, V_FATGERALMETA, V_FATGERALANT,V_CODEMP
            FROM AD_TMTFAT WHERE CODMETA = V_CODMETA
                AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                V_DTINI:= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');
                V_DTFIN:= TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));
                V_FATGERALMETA:= 0;
                V_FATGERALANT:= 0;
                V_CODEMP:= NVL(GET_TSIPAR_INTEIRO('DEFAULTEMP'), 1);
        END;

        V_FATPROD:= JS_FC_CALC_FAT(P_DTINI => V_DTINI, P_DTFIN => V_DTFIN,P_CODPROD => V_CODPROD, P_CODEMP => V_CODEMP);
        V_QTDNEG:= JS_FC_CALC_FAT(P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODPROD => V_CODPROD, P_CODEMP => V_CODEMP, P_ITENEG => 'S');
        V_TCKAVG:= ROUND(NVL(V_FATPROD, 0) / NULLIF(V_QTDNEG, 0), CSDEC);
        V_SUMFAT:= V_FATPROD + NVL(V_FATEST, 0); 
        V_PTCPROD:= ROUND(NVL(V_SUMFAT / NULLIF(V_FATGERALANT, 0) *100, 0), CSDEC);
        V_AVPROD:= V_SUMFAT * (NVL(V_AVPRODPERC, 0) / 100);
        V_PXMETA:= ROUND(NVL(V_FATGERALMETA, 0) * (V_PTCPROD/100) * (1+ NVL(V_PTCPRODCRESC,0) /100), CSDEC);
        V_VARPERC:= ROUND(NVL((V_PXMETA - V_SUMFAT) / NULLIF(V_SUMFAT, 0) *100, 0), CSDEC);
        V_METAITE:= CEIL(NVL(V_PXMETA, 0) / NULLIF(V_TCKAVG, 0));

        EVP_SET_CAMPO_DEC(P_IDSESSAO,'FATPROD', V_FATPROD);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'VPERCPROD',V_VARPERC);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'PTCPROD',V_PTCPROD);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'AVPROD',V_AVPROD);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'PXMETA',V_PXMETA);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'QTDNEG',V_QTDNEG);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'TCKAVG',V_TCKAVG);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'QTDNEGMETA',V_METAITE);  

        IF P_TIPOEVENTO = BEFORE_UPDATE THEN
            UPDATE AD_TMTFAT SET 
                DHALTER = SYSDATE, 
                CODUSU = P_CODUSU
            WHERE CODMETA = V_CODMETA;
        END IF;

    ELSIF P_DTINI IS NOT NULL AND P_DTFIN IS NOT NULL AND P_CODMETA IS NOT NULL THEN

                --<<< Bloco disparado por TRIGGER ou Loop de Polulação de grade >>>--

        --Desvia o fluxo da Trigger
        IF P_FATGERAL IS NOT NULL AND P_FATGERALMETA IS NOT NULL THEN
            V_FATGERALANT:= P_FATGERAL;
            V_FATGERALMETA:= P_FATGERALMETA;
        ELSE
            BEGIN
                SELECT FATGERALMETA, FATGERAL
                INTO V_FATGERALMETA, V_FATGERALANT
                FROM AD_TMTFAT 
                WHERE CODMETA = P_CODMETA;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    V_FATGERALMETA:= 0;
                    V_FATGERALANT:= 0;
            END;
        END IF;

        DECLARE
            -- Declaração dos Tipos de coleção (Tabela em memória)
            TYPE T_NRORESPRO     IS TABLE OF  AD_TMTFATRTPRO.NRORESPRO%TYPE;
            TYPE T_CODPROD       IS TABLE OF  AD_TMTFATRTPRO.CODPROD%TYPE;
            TYPE T_FATESTIPRO    IS TABLE OF  AD_TMTFATRTPRO.FATESTIPRO%TYPE;
            TYPE T_AVPRODPERC    IS TABLE OF  AD_TMTFATRTPRO.AVPRODPERC%TYPE;
            TYPE T_PTCPRODCRESC  IS TABLE OF  AD_TMTFATRTPRO.PTCPRODCRESC%TYPE;

            TYPE T_FATPROD       IS TABLE OF AD_TMTFATRTPRO.FATPROD%TYPE;
            TYPE T_PTCPROD       IS TABLE OF AD_TMTFATRTPRO.PTCPROD%TYPE;
            TYPE T_AVPROD        IS TABLE OF AD_TMTFATRTPRO.AVPROD%TYPE;
            TYPE T_PXMETA        IS TABLE OF AD_TMTFATRTPRO.PXMETA%TYPE;
            TYPE T_VPERCPROD     IS TABLE OF AD_TMTFATRTPRO.VPERCPROD%TYPE;
            TYPE T_QTDNEG        IS TABLE OF AD_TMTFATRTPRO.QTDNEG%TYPE;
            TYPE T_TCKAVG        IS TABLE OF AD_TMTFATRTPRO.TCKAVG%TYPE;
            TYPE T_METAITE       IS TABLE OF AD_TMTFATRTPRO.QTDNEGMETA%TYPE;
            --Declaração das Variáveis da coleção (Incializadas no Bulk Collect)
            V_ARR_NRO        T_NRORESPRO;
            V_ARR_CODPROD    T_CODPROD;
            V_ARR_FATEST     T_FATESTIPRO;
            V_ARR_AVPERC     T_AVPRODPERC;
            V_ARR_CRESC      T_PTCPRODCRESC;
            --Inicialização manual das coleções
            V_ARR_FATPROD    T_FATPROD:= T_FATPROD();
            V_ARR_PTCPROD    T_PTCPROD:= T_PTCPROD();
            V_ARR_AVPROD     T_AVPROD:= T_AVPROD();
            V_ARR_PXMETA     T_PXMETA:= T_PXMETA();
            V_ARR_VARPERC    T_VPERCPROD:= T_VPERCPROD();
            V_ARR_QTDNEG     T_QTDNEG:= T_QTDNEG();
            V_ARR_TCKAVG     T_TCKAVG:= T_TCKAVG();
            V_ARR_METAITE    T_METAITE:= T_METAITE();
        BEGIN
            SELECT NRORESPRO, CODPROD, FATESTIPRO, AVPRODPERC, PTCPRODCRESC
            BULK COLLECT INTO V_ARR_NRO, V_ARR_CODPROD, V_ARR_FATEST, V_ARR_AVPERC, V_ARR_CRESC
            FROM AD_TMTFATRTPRO
            WHERE CODMETA = P_CODMETA;

            IF V_ARR_NRO.COUNT > 0 THEN 
                -- Dimensiona os arrays com o mesmo tamanho dos dados lidos (Pela PK)
                V_ARR_FATPROD.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_PTCPROD.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_AVPROD.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_PXMETA.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_VARPERC.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_QTDNEG.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_TCKAVG.EXTEND(V_ARR_NRO.COUNT);
                V_ARR_METAITE.EXTEND(V_ARR_NRO.COUNT);

                FOR y IN 1.. V_ARR_NRO.COUNT --(Limite superior)
                LOOP
                    V_ARR_FATPROD(y) := JS_FC_CALC_FAT(
                                        P_DTINI => P_DTINI, 
                                        P_DTFIN => P_DTFIN, 
                                        P_CODPROD => V_ARR_CODPROD(y), 
                                        P_CODEMP => P_CODEMP);

                    V_ARR_QTDNEG(y)  := JS_FC_CALC_FAT(
                                        P_DTINI => P_DTINI, 
                                        P_DTFIN => P_DTFIN, 
                                        P_CODPROD => V_ARR_CODPROD(y), 
                                        P_CODEMP => P_CODEMP, 
                                        P_ITENEG => 'S');

                    V_ARR_TCKAVG(y)  := ROUND(NVL(V_ARR_FATPROD(y), 0) / NULLIF(V_ARR_QTDNEG(y), 0), CSDEC);
                    V_SUMFAT         := NVL(V_ARR_FATPROD(y), 0) + NVL(V_ARR_FATEST(y), 0); 
                    V_ARR_PTCPROD(y) := ROUND(NVL(V_SUMFAT / NULLIF(V_FATGERALANT, 0) * 100, 0), CSDEC);
                    V_ARR_AVPROD(y)  := V_SUMFAT * (NVL(V_ARR_AVPERC(y), 0) / 100);
                    V_ARR_PXMETA(y)  := ROUND(NVL(V_FATGERALMETA, 0) * (V_ARR_PTCPROD(y) / 100) * (1 + NVL(V_ARR_CRESC(y), 0) / 100), CSDEC);
                    V_ARR_VARPERC(y) := ROUND(NVL((V_ARR_PXMETA(y) - V_SUMFAT) / NULLIF(V_SUMFAT, 0) * 100, 0), CSDEC);
                    V_ARR_METAITE(y) := CEIL(NVL(V_ARR_PXMETA(y), 0) / NULLIF(V_ARR_TCKAVG(y), 0));
                END LOOP;
                --Reduz a troca de contexto entre PL/SQL e SQL (Envio em massa - Baseado em exemplo da oracle)
                FORALL y IN 1 .. V_ARR_NRO.COUNT
                    UPDATE AD_TMTFATRTPRO SET
                        FATPROD   = V_ARR_FATPROD(y),
                        QTDNEG    = V_ARR_QTDNEG(y),
                        TCKAVG    = V_ARR_TCKAVG(y),
                        QTDNEGMETA = V_ARR_METAITE(y),
                        PTCPROD   = V_ARR_PTCPROD(y),
                        AVPROD    = V_ARR_AVPROD(y),
                        PXMETA    = V_ARR_PXMETA(y),
                        VPERCPROD = V_ARR_VARPERC(y)
                    WHERE CODMETA = P_CODMETA
                        AND NRORESPRO = V_ARR_NRO(y);
            END IF;
        END;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, '<b>Erro:</b> Não foi possível calcular o faturamento do produto na meta.' || SQLERRM);
END;
