CREATE OR REPLACE PROCEDURE JS_STP_CALC_RES_VEN_PCR (
    P_TIPOEVENTO INT DEFAULT NULL,
    P_IDSESSAO VARCHAR2 DEFAULT NULL,
    P_CODUSU INT DEFAULT NULL,
    --Parametros de entrada disparados por Trigger e STP de explosão de registros (Padrão nulo, pra não dá erro em eventos)
    P_DTINI           IN DATE DEFAULT NULL,      
    P_DTFIN           IN DATE DEFAULT NULL,  
    P_CODMETA         IN INT DEFAULT NULL,
    P_CODEMP          IN INT DEFAULT NULL,
    
    P_FATVEN          IN NUMBER DEFAULT NULL,
    P_METAVEN         IN INT DEFAULT NULL
) AS 
    BEFORE_INSERT INT:= 0;
    BEFORE_UPDATE INT:= 4;

    V_CODMETA       AD_TMTFATRTVENPCR.CODMETA%TYPE;     
    V_CODPARC       AD_TMTFATRTVENPCR.CODPARC%TYPE;   
    V_NRORESVEN     AD_TMTFATRTVENPCR.NRORESVEN%TYPE;
    V_PTCPCR        AD_TMTFATRTVENPCR.PTCPCR%TYPE;      
    V_FATPCR        AD_TMTFATRTVENPCR.FATPCR%TYPE;      
    V_AVPCR         AD_TMTFATRTVENPCR.AVPCR%TYPE;       
    V_AVPCRPERC     AD_TMTFATRTVENPCR.AVPCRPERC%TYPE;   
    V_PTCPCRCRESC   AD_TMTFATRTVENPCR.PTCPCRCRESC%TYPE;
    V_PXMETA        AD_TMTFATRTVENPCR.PXMETA%TYPE;
    V_FATEST        AD_TMTFATRTVENPCR.FATESTIPCR%TYPE;   
    V_VARPERC       AD_TMTFATRTVENPCR.VPERCPCR%TYPE;
    V_SUMFAT        NUMBER;
    V_FATESTIVEN    NUMBER;

    V_METAVEN       AD_TMTFATRTVEN.PXMETA%TYPE;
    V_CODVEND       AD_TMTFATRTVEN.CODVEND%TYPE;        
    V_FATVEN        AD_TMTFATRTVEN.FATVEN%TYPE;         
    V_DTINI         AD_TMTFAT.DTINI%TYPE;               
    V_DTFIN         AD_TMTFAT.DTFIN%TYPE;               
    V_CODEMP        AD_TMTFAT.CODEMP%TYPE;
    V_IMPORT_MOV    VARCHAR2(1);
    CSDEC           INT;
    V_NEW_META      AD_TMTFATRTVENPCR.PXMETA%TYPE;
BEGIN
    CSDEC:= NVL(GET_TSIPAR_INTEIRO('CSDEC'), 2);

      --Bloco de Cálculo manual
    IF P_TIPOEVENTO = BEFORE_INSERT OR P_TIPOEVENTO = BEFORE_UPDATE THEN

        V_CODMETA:= EVP_GET_CAMPO_INT(P_IDSESSAO,'CODMETA');
        V_CODPARC:= EVP_GET_CAMPO_INT(P_IDSESSAO,'CODPARC');
        V_NRORESVEN:= EVP_GET_CAMPO_INT(P_IDSESSAO, 'NRORESVEN');
        V_AVPCRPERC:= NVL(EVP_GET_CAMPO_DEC(P_IDSESSAO,'AVPCRPERC'), 2);
        V_PTCPCRCRESC:= EVP_GET_CAMPO_DEC(P_IDSESSAO,'PTCPCRCRESC');
        V_FATEST:= EVP_GET_CAMPO_DEC(P_IDSESSAO,'FATESTIPCR');
        V_FATPCR:= EVP_GET_CAMPO_DEC(P_IDSESSAO,'FATPCR');
        V_IMPORT_MOV:= NVL(EVP_GET_CAMPO_TEXTO(P_IDSESSAO,'MOVIMPORTVEN'),'N');

        IF V_CODMETA IS NULL  THEN
            RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Não foi possível indentificar o código da meta.</b>');
        ELSIF V_CODPARC IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Preencha o código do parceiro.</b>');
        END IF;

        --Busca os dados da tabela Mestre
        BEGIN
            SELECT DTINI, DTFIN, CODEMP
            INTO V_DTINI, V_DTFIN, V_CODEMP
            FROM AD_TMTFAT 
            WHERE CODMETA = V_CODMETA
                AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                V_DTINI:= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');
                V_DTFIN:= TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));
                V_CODEMP:= NVL(GET_TSIPAR_INTEIRO('DEFAULTEMP'), 1);
        END;
            --Captura o CODVEND da tabela pai
        BEGIN
            SELECT CODVEND, FATVEN, PXMETA
            INTO V_CODVEND, V_FATVEN, V_METAVEN
            FROM AD_TMTFATRTVEN 
            WHERE NRORESVEN = V_NRORESVEN
                AND CODMETA = V_CODMETA
                AND ROWNUM = 1;
        EXCEPTION 
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001,'Erro: <b>Vendedor parceiro não encontrado na meta: </b>' || TO_CHAR(V_CODMETA));
        END;
        --Flag de controle, indica que as movimentações vieram de outro vendedor.
        IF V_IMPORT_MOV !='N' THEN
            V_FATPCR:= NVL(V_FATPCR, 0);
        ELSE
            V_FATPCR:= JS_FC_CALC_FAT(P_DTINI => V_DTINI,P_DTFIN => V_DTFIN,P_CODVEND => V_CODVEND,P_CODPARC => V_CODPARC,P_CODEMP => V_CODEMP);
        END IF;

        V_SUMFAT:= NVL(V_FATPCR, 0) + NVL(V_FATEST,0);
        V_PTCPCR:= ROUND(NVL((V_FATPCR / NULLIF(V_FATVEN, 0)) * 100,0), CSDEC);
        V_AVPCR:= NVL(V_SUMFAT, 0) * (NVL(V_AVPCRPERC, 0) / 100);
        V_PXMETA:= ROUND(NVL(V_METAVEN, 0) * (V_PTCPCR/100) + NVL(V_FATEST,0) * (1+ NVL(V_PTCPCRCRESC, 0) /100), CSDEC);
        V_VARPERC:= ROUND(NVL((V_PXMETA - V_SUMFAT) / NULLIF(V_SUMFAT, 0) *100, 0), CSDEC);

        EVP_SET_CAMPO_DEC(P_IDSESSAO,'FATPCR', V_FATPCR);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'PTCPCR', V_PTCPCR);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'AVPCR', V_AVPCR);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'PXMETA', V_PXMETA);
        EVP_SET_CAMPO_DEC(P_IDSESSAO,'VPERCPCR', V_VARPERC);

        IF P_TIPOEVENTO = BEFORE_UPDATE THEN
            SELECT SUM(PXMETA)
            INTO V_NEW_META
            FROM AD_TMTFATRTVENPCR
            WHERE CODMETA = V_CODMETA
                AND NRORESVEN = V_NRORESVEN
                AND CODPARC != V_CODPARC;

            V_NEW_META:= NVL(V_NEW_META, 0) + NVL(V_PXMETA, 0);

            UPDATE AD_TMTFATRTVEN SET
                PXMETA = V_NEW_META
            WHERE CODMETA = V_CODMETA
                AND NRORESVEN = V_NRORESVEN;
        END IF;

        --Registra usuário,data e hora de alteração (Antes de inserir ou atualizar)
        UPDATE AD_TMTFAT SET 
            DHALTER = SYSDATE, 
            CODUSU = P_CODUSU 
        WHERE CODMETA = V_CODMETA;

    ELSIF P_DTINI IS NOT NULL AND P_DTFIN IS NOT NULL AND P_CODMETA IS NOT NULL THEN

                --<<< Bloco disparado por TRIGGER ou Loop de Polulação de grade >>>--
        DECLARE
            -- Declaração dos Tipos de coleção (Tabela em memória)
            TYPE T_NRORESPCR    IS TABLE OF AD_TMTFATRTVENPCR.NRORESPCR%TYPE;
            TYPE T_CODPARC      IS TABLE OF AD_TMTFATRTVENPCR.CODPARC%TYPE;
            TYPE T_FATESTIPCR   IS TABLE OF AD_TMTFATRTVENPCR.FATESTIPCR%TYPE;
            TYPE T_AVPCRPERC    IS TABLE OF AD_TMTFATRTVENPCR.AVPCRPERC%TYPE;
            TYPE T_PTCPCRCRESC  IS TABLE OF AD_TMTFATRTVENPCR.PTCPCRCRESC%TYPE;
            TYPE T_MOVIMPORT    IS TABLE OF AD_TMTFATRTVENPCR.MOVIMPORTVEN%TYPE;
            TYPE T_FATPCRSLC    IS TABLE OF AD_TMTFATRTVENPCR.FATPCR%TYPE;

            TYPE T_NRORESVEN    IS TABLE OF AD_TMTFATRTVEN.NRORESVEN%TYPE;
            TYPE T_CODVEND      IS TABLE OF AD_TMTFATRTVEN.CODVEND%TYPE;
            TYPE T_FATVEN       IS TABLE OF AD_TMTFATRTVEN.FATVEN%TYPE;
            TYPE T_PXMETAVEN    IS TABLE OF AD_TMTFATRTVEN.PXMETA%TYPE;

            TYPE T_FATPCR       IS TABLE OF AD_TMTFATRTVENPCR.FATPCR%TYPE;
            TYPE T_PTCPCR       IS TABLE OF AD_TMTFATRTVENPCR.PTCPCR%TYPE;
            TYPE T_AVPCR        IS TABLE OF AD_TMTFATRTVENPCR.AVPCR%TYPE;
            TYPE T_PXMETA       IS TABLE OF AD_TMTFATRTVENPCR.PXMETA%TYPE;
            TYPE T_VPERCPCR     IS TABLE OF AD_TMTFATRTVENPCR.VPERCPCR%TYPE;

            V_ARR_NRORESPCR     T_NRORESPCR;
            V_ARR_CODPARC       T_CODPARC;
            V_ARR_FATEST        T_FATESTIPCR;
            V_ARR_AVPCRPERC     T_AVPCRPERC;
            V_ARR_CRESC         T_PTCPCRCRESC;
            V_ARR_MOVIMPORT     T_MOVIMPORT;
            V_ARR_FATPCRSLC     T_FATPCRSLC;

            V_ARR_RESVEN        T_NRORESVEN;
            V_ARR_CODVEND       T_CODVEND;
            V_ARR_FATVEN        T_FATVEN;
            V_ARR_PXMETAVEN     T_PXMETAVEN;

            V_ARR_FATPCR        T_FATPCR:= T_FATPCR();
            V_ARR_PTCPCR        T_PTCPCR:= T_PTCPCR();
            V_ARR_AVPCR         T_AVPCR:= T_AVPCR();
            V_ARR_PXMETA        T_PXMETA:= T_PXMETA();
            V_ARR_VPERCPCR      T_VPERCPCR:= T_VPERCPCR();
        BEGIN
            SELECT 
                VEN.NRORESVEN, VEN.CODVEND, VEN.FATVEN, VEN.PXMETA, PCR.NRORESPCR, PCR.CODPARC, PCR.FATESTIPCR, 
                PCR.AVPCRPERC, PCR.PTCPCRCRESC, PCR.MOVIMPORTVEN, PCR.FATPCR
            BULK COLLECT INTO 
                V_ARR_RESVEN, V_ARR_CODVEND, V_ARR_FATVEN, V_ARR_PXMETAVEN, V_ARR_NRORESPCR, V_ARR_CODPARC, 
                V_ARR_FATEST, V_ARR_AVPCRPERC, V_ARR_CRESC, V_ARR_MOVIMPORT, V_ARR_FATPCRSLC
            FROM AD_TMTFATRTVENPCR PCR
            JOIN AD_TMTFATRTVEN VEN ON VEN.NRORESVEN = PCR.NRORESVEN
            WHERE PCR.CODMETA = P_CODMETA;

            IF V_ARR_NRORESPCR.COUNT > 0 THEN 
            
                V_ARR_FATPCR.EXTEND(V_ARR_NRORESPCR.COUNT);
                V_ARR_PTCPCR.EXTEND(V_ARR_NRORESPCR.COUNT);
                V_ARR_AVPCR.EXTEND(V_ARR_NRORESPCR.COUNT);
                V_ARR_PXMETA.EXTEND(V_ARR_NRORESPCR.COUNT);
                V_ARR_VPERCPCR.EXTEND(V_ARR_NRORESPCR.COUNT);

                FOR y IN 1.. V_ARR_NRORESPCR.COUNT --(Limite superior)
                LOOP
                    IF NVL(V_ARR_MOVIMPORT(y),'N') != 'N' THEN
                        V_ARR_FATPCR(y):= NVL(V_ARR_FATPCRSLC(y), 0);
                    ELSE
                        V_ARR_FATPCR(y):= JS_FC_CALC_FAT(
                                        P_DTINI => P_DTINI, 
                                        P_DTFIN => P_DTFIN, 
                                        P_CODVEND => V_ARR_CODVEND(y), 
                                        P_CODPARC => V_ARR_CODPARC(y),
                                        P_CODEMP => P_CODEMP
                                    );
                    END IF;
                        V_SUMFAT:= NVL(V_ARR_FATPCR(y), 0) + NVL(V_ARR_FATEST(y), 0);
                        V_ARR_PTCPCR(y):= ROUND(NVL((V_ARR_FATPCR(y) / NULLIF(V_ARR_FATVEN(y), 0)) * 100, 0), CSDEC);
                        V_ARR_AVPCR(y):= NVL(V_SUMFAT, 0) * (NVL(V_ARR_AVPCRPERC(y), 0) / 100);
                        V_ARR_PXMETA(y):= ROUND(NVL(V_ARR_PXMETAVEN(y), 0) * (V_ARR_PTCPCR(y) /100) * (1 + NVL(V_ARR_CRESC(y), 0) / 100), CSDEC);
                        V_ARR_VPERCPCR(y):= ROUND(NVL((V_ARR_PXMETA(y) - V_SUMFAT) * (V_ARR_PTCPCR(y) /100), 0), CSDEC);
                END LOOP;

                FORALL y IN 1 .. V_ARR_NRORESPCR.COUNT
                    UPDATE AD_TMTFATRTVENPCR SET
                        FATPCR = V_ARR_FATPCR(y),
                        PTCPCR = V_ARR_PTCPCR(y),
                        AVPCR = V_ARR_AVPCR(y),
                        PXMETA = V_ARR_PXMETA(y),
                        VPERCPCR = V_ARR_VPERCPCR(y)
                    WHERE CODMETA = P_CODMETA
                        AND NRORESVEN = V_ARR_RESVEN(y)
                        AND NRORESPCR = V_ARR_NRORESPCR(y);
            END IF;
        END;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, '<b>Erro:</b> Não foi possível calcular o faturamento do Parceiro na meta.' || SQLERRM);
END;
