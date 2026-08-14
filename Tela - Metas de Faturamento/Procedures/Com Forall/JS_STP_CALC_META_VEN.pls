CREATE OR REPLACE PROCEDURE JS_STP_CALC_META_VEN (
    P_TIPOEVENTO INT DEFAULT NULL,
    P_IDSESSAO VARCHAR2 DEFAULT NULL,
    P_CODUSU INT DEFAULT NULL,
  --Parametros de entrada disparados por Trigger e STP de explosão de registros (Padrão nulo, pra não dá erro em eventos)
    P_DTINI                 IN DATE DEFAULT NULL,      
    P_DTFIN                 IN DATE DEFAULT NULL,  
    P_CODMETA               IN INT DEFAULT NULL,
    P_FATGERALMETA          IN NUMBER DEFAULT NULL, 
    P_FATGERAL              IN NUMBER DEFAULT NULL,
    P_CODEMP                IN INT DEFAULT NULL,
    --ParametroS de entrada, indica importação de dados de outros vendedores (Flag)
    P_MOV_IMPORT            IN VARCHAR2 DEFAULT NULL,
    P_FATEST                IN NUMBER DEFAULT NULL,
    P_PTCVENCRESC           IN NUMBER DEFAULT NULL,
    P_CODVEND               IN NUMBER DEFAULT NULL,
    P_AVPERC                IN NUMBER DEFAULT NULL,
    P_FATVEN                IN NUMBER DEFAULT NULL
) AS 
    BEFORE_INSERT INT:= 0;
    BEFORE_UPDATE INT:= 4;

    V_CODMETA        AD_TMTFATRTVEN.CODMETA%TYPE;        
    V_CODVEND        AD_TMTFATRTVEN.CODVEND%TYPE;        
    V_AVVENPERC      AD_TMTFATRTVEN.AVVENPERC%TYPE;      
    V_PTCVENCRESC    AD_TMTFATRTVEN.PTCVENCRESC%TYPE;    

    V_DTINI          AD_TMTFAT.DTINI%TYPE;          
    V_DTFIN          AD_TMTFAT.DTFIN%TYPE;           
    V_FATGERALANT    AD_TMTFAT.FATGERAL%TYPE;        
    V_FATGERALMETA   AD_TMTFAT.FATGERALMETA%TYPE;
    V_CODEMP         AD_TMTFAT.CODEMP%TYPE;

    V_FATVEN         AD_TMTFATRTVEN.FATVEN%TYPE;         
    V_PTCVEN         AD_TMTFATRTVEN.PTCVEN%TYPE;         
    V_AVVEN          AD_TMTFATRTVEN.AVVEN%TYPE;          
    V_PXMETA         AD_TMTFATRTVEN.PXMETA%TYPE;
    V_FATEST         AD_TMTFATRTVEN.FATESTIVEN%TYPE;   
    V_VARPERC        AD_TMTFATRTVEN.VPERCVEN%TYPE;
    V_SUMFAT         NUMBER;
    V_MOV_IMPORT     VARCHAR(1);
    CSDEC            INT;
BEGIN
    CSDEC:= NVL(GET_TSIPAR_INTEIRO('CSDEC'), 2);
      --Bloco de Cálculo manual
    IF P_TIPOEVENTO = BEFORE_INSERT OR P_TIPOEVENTO = BEFORE_UPDATE THEN

        V_CODMETA:= COALESCE(EVP_GET_CAMPO_INT(P_IDSESSAO,'CODMETA'), P_CODMETA);
        V_AVVENPERC:= COALESCE(EVP_GET_CAMPO_DEC(P_IDSESSAO,'AVVENPERC'), P_AVPERC, 2);
        V_PTCVENCRESC:= COALESCE(EVP_GET_CAMPO_DEC(P_IDSESSAO,'PTCVENCRESC'), P_PTCVENCRESC, 0);
        V_CODVEND:= COALESCE(EVP_GET_CAMPO_INT(P_IDSESSAO,'CODVEND'), P_CODVEND);
        V_FATVEN:= COALESCE(EVP_GET_CAMPO_DEC(P_IDSESSAO,'FATVEN'), P_FATVEN, 0);
        V_FATEST:= COALESCE(EVP_GET_CAMPO_DEC(P_IDSESSAO,'FATESTIVEN'), P_FATEST, 0);
        V_MOV_IMPORT:= COALESCE(EVP_GET_CAMPO_TEXTO(P_IDSESSAO,'MOVIMPORTVEN'), P_MOV_IMPORT,'N');

        IF V_CODMETA IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Não foi possível identificar o código da meta.</b>');
        ELSIF V_CODVEND IS NULL THEN 
            RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Preencha o código do vendedor.</b>');
        END IF;

        --Busca os dados da tabela Mestre
        BEGIN
            SELECT DTINI, DTFIN, FATGERALMETA, FATGERAL, CODEMP
            INTO V_DTINI, V_DTFIN, V_FATGERALMETA, V_FATGERALANT, V_CODEMP
            FROM AD_TMTFAT 
            WHERE CODMETA = V_CODMETA
                AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                V_DTINI:= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');
                V_DTFIN:= TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));
                V_FATGERALMETA:= 0;
                V_FATGERALANT:= 0;
                V_CODEMP:= NVL(GET_TSIPAR_INTEIRO('DEFAULTEMP'), 1);
        END;
            --Parâmetro de entrada STP
        IF V_MOV_IMPORT !='N' THEN
            V_FATVEN:= V_FATVEN;
        ELSE
            V_FATVEN:= JS_FC_CALC_FAT(P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODVEND => V_CODVEND,P_CODEMP => V_CODEMP);
        END IF;

        V_SUMFAT:= V_FATVEN + V_FATEST;
        V_PTCVEN:= ROUND(NVL((V_SUMFAT / NULLIF(V_FATGERALANT, 0)) * 100, 0), CSDEC);
        V_AVVEN:= V_SUMFAT * (V_AVVENPERC / 100);
        V_PXMETA:= ROUND(NVL(V_FATGERALMETA, 0) * (V_PTCVEN/100) * (1 + (V_PTCVENCRESC / 100)), CSDEC);
        V_VARPERC:= ROUND(NVL((V_PXMETA - V_SUMFAT) / NULLIF(V_SUMFAT, 0) *100, 0), CSDEC);

        EVP_SET_CAMPO_DEC(P_IDSESSAO,'FATVEN', V_FATVEN);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'VPERCVEN',V_VARPERC);
        EVP_SET_CAMPO_DEC(P_IDSESSAO, 'PTCVEN', V_PTCVEN);
        EVP_SET_CAMPO_DEC(P_IDSESSAO, 'AVVEN', V_AVVEN);
        EVP_SET_CAMPO_DEC(P_IDSESSAO, 'PXMETA', V_PXMETA); 

        --Presistência forçada por conta da STP de importação, ela não consegue acionar as Functions acima, estão fora de contexto.
        IF P_IDSESSAO IS NOT NULL AND NVL(P_MOV_IMPORT,'N') != 'N' THEN
            UPDATE AD_TMTFATRTVEN SET
                PTCVEN   = V_PTCVEN,
                AVVEN    = V_AVVEN,
                PXMETA   = V_PXMETA,
                VPERCVEN = V_VARPERC
            WHERE CODMETA = V_CODMETA 
                AND CODVEND = V_CODVEND;
        END IF;
         --Chamada para recalculo dos parceiro e produtos
        IF P_TIPOEVENTO = BEFORE_UPDATE THEN 
            JS_STP_UPT_PCR_PRO (P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODEMP => V_CODEMP, P_CODMETA => V_CODMETA,
                                P_CODVEND => V_CODVEND, P_FATVEN => V_FATVEN, P_METAVEN => V_PXMETA);
        END IF;
        --Registra usuário,data e hora de alteração (Antes de inserir ou atualizar)
        UPDATE AD_TMTFAT SET 
            DHALTER = SYSDATE, 
            CODUSU = P_CODUSU 
        WHERE CODMETA = V_CODMETA;

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
            TYPE T_NRORESVEN    IS TABLE OF AD_TMTFATRTVEN.NRORESVEN%TYPE;
            TYPE T_CODVEND      IS TABLE OF AD_TMTFATRTVEN.CODVEND%TYPE;
            TYPE T_FATESTIVEN   IS TABLE OF AD_TMTFATRTVEN.FATESTIVEN%TYPE;
            TYPE T_AVVENPERC    IS TABLE OF AD_TMTFATRTVEN.AVVENPERC%TYPE;
            TYPE T_PTCVENCRESC  IS TABLE OF AD_TMTFATRTVEN.PTCVENCRESC%TYPE;
            TYPE T_MOVIMPORT    IS TABLE OF AD_TMTFATRTVEN.MOVIMPORTVEN%TYPE;
            TYPE T_FATVENSLC    IS TABLE OF AD_TMTFATRTVEN.FATVEN%TYPE;

            TYPE T_FATVEN       IS TABLE OF AD_TMTFATRTVEN.FATVEN%TYPE;
            TYPE T_PTCVEN       IS TABLE OF AD_TMTFATRTVEN.PTCVEN%TYPE;
            TYPE T_AVVEN        IS TABLE OF AD_TMTFATRTVEN.AVVEN%TYPE;
            TYPE T_PXMETA       IS TABLE OF AD_TMTFATRTVEN.PXMETA%TYPE;
            TYPE T_VPERCVEN     IS TABLE OF AD_TMTFATRTVEN.VPERCVEN%TYPE;

            --Declaração das Variáveis da coleção (Incializadas no Bulk Collect)
            V_ARR_RESVEN    T_NRORESVEN;
            V_ARR_CODVEND   T_CODVEND;
            V_ARR_FATESTI   T_FATESTIVEN;
            V_ARR_AVPERC    T_AVVENPERC;
            V_ARR_CRESC     T_PTCVENCRESC;
            V_ARR_MOVIMPORT T_MOVIMPORT;                                                                                                                           
            V_ARR_FATVENSLC T_FATVENSLC;                                                    

            --Inicialização manual das coleções
            V_ARR_FATVEN    T_FATVEN    := T_FATVEN();
            V_ARR_PTCVEN    T_PTCVEN    := T_PTCVEN();
            V_ARR_AVVEN     T_AVVEN     := T_AVVEN();
            V_ARR_PXMETA    T_PXMETA    := T_PXMETA();
            V_ARR_VPERCVEN  T_VPERCVEN  := T_VPERCVEN();
        BEGIN

            SELECT NRORESVEN, CODVEND, FATESTIVEN, AVVENPERC, PTCVENCRESC, MOVIMPORTVEN, FATVEN
            BULK COLLECT INTO V_ARR_RESVEN, V_ARR_CODVEND, V_ARR_FATESTI, V_ARR_AVPERC, V_ARR_CRESC, V_ARR_MOVIMPORT, V_ARR_FATVENSLC
            FROM AD_TMTFATRTVEN
            WHERE CODMETA = P_CODMETA;

            IF V_ARR_RESVEN.COUNT > 0 THEN
                -- Dimensiona os arrays com o mesmo tamanho dos dados lidos (Pela PK)
                V_ARR_FATVEN.EXTEND(V_ARR_RESVEN.COUNT);
                V_ARR_PTCVEN.EXTEND(V_ARR_RESVEN.COUNT);
                V_ARR_AVVEN.EXTEND(V_ARR_RESVEN.COUNT);
                V_ARR_PXMETA.EXTEND(V_ARR_RESVEN.COUNT);
                V_ARR_VPERCVEN.EXTEND(V_ARR_RESVEN.COUNT);

                FOR y IN 1.. V_ARR_RESVEN.COUNT --(Limite superior)
                LOOP
                    IF NVL(V_ARR_MOVIMPORT(y),'N') != 'N' THEN
                        V_ARR_FATVEN(y):= NVL(V_ARR_FATVENSLC(y), 0);
                    ELSE
                        V_ARR_FATVEN(y):= JS_FC_CALC_FAT(
                                        P_DTINI => P_DTINI, 
                                        P_DTFIN => P_DTFIN, 
                                        P_CODVEND => V_ARR_CODVEND(y), 
                                        P_CODEMP => P_CODEMP
                                    );
                    END IF;
                        V_SUMFAT:= V_ARR_FATVEN(y) + NVL(V_ARR_FATESTI(y), 0);
                        V_ARR_PTCVEN(y):= ROUND(NVL((V_SUMFAT / NULLIF(V_FATGERALANT, 0)) * 100, 0), CSDEC);
                        V_ARR_AVVEN(y):= NVL(V_SUMFAT, 0) * (NVL(V_ARR_AVPERC(y), 0) /100);
                        V_ARR_PXMETA(y):= ROUND(NVL(V_FATGERALMETA, 0) * (V_ARR_PTCVEN(y) /100) * (1 + NVL(V_ARR_CRESC(y), 0) /100), CSDEC);
                        V_ARR_VPERCVEN(y):= ROUND(NVL((V_ARR_PXMETA(y) - V_SUMFAT) / NULLIF(V_SUMFAT, 0) *100, 0), CSDEC);
                END LOOP;

                FORALL y IN 1 .. V_ARR_RESVEN.COUNT
                    UPDATE AD_TMTFATRTVEN SET
                        FATVEN = V_ARR_FATVEN(y),
                        PTCVEN = V_ARR_PTCVEN(y),
                        AVVEN = V_ARR_AVVEN(y),
                        PXMETA = V_ARR_PXMETA(y),
                        VPERCVEN = V_ARR_VPERCVEN(y)
                    WHERE CODMETA = P_CODMETA 
                        AND NRORESVEN = V_ARR_RESVEN(Y);
            END IF;
        END;
    END IF;
EXCEPTION
  WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, '<b>Erro:</b> Não foi possível calcular o faturamento do Vendedor na meta.' || SQLERRM);
END;

