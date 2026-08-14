create or replace PROCEDURE JS_STP_CALC_RES_VEN_PCR (

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
            V_SUMFAT:= V_FATPCR + NVL(V_FATEST,0);
        ELSE
            V_FATPCR:= JS_FC_CALC_FAT(P_DTINI => V_DTINI,P_DTFIN => V_DTFIN,P_CODVEND => V_CODVEND,P_CODPARC => V_CODPARC,P_CODEMP => V_CODEMP);
            V_SUMFAT:= NVL(V_FATPCR, 0) + NVL(V_FATEST,0);
        END IF;

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
        V_DTINI:= P_DTINI;
        V_DTFIN:= P_DTFIN;
        V_CODEMP:= P_CODEMP;

        FOR I IN (
            SELECT 
                PCR.NRORESPCR,
                PCR.CODPARC,
                PCR.FATESTIPCR,
                PCR.FATPCR,
                PCR.AVPCRPERC, 
                PCR.PTCPCRCRESC,
                PCR.MOVIMPORTVEN,
                VEN.NRORESVEN,
                VEN.CODVEND,
                VEN.FATVEN,
                VEN.PXMETA
                FROM AD_TMTFATRTVENPCR PCR
                JOIN AD_TMTFATRTVEN VEN ON VEN.NRORESVEN = PCR.NRORESVEN
            WHERE PCR.CODMETA = P_CODMETA
        ) LOOP

            IF NVL(I.MOVIMPORTVEN,'N') != 'N' THEN
                V_FATPCR:= NVL(I.FATPCR, 0);
            ELSE
                V_FATPCR:= JS_FC_CALC_FAT(P_DTINI => P_DTINI, P_DTFIN => P_DTFIN, P_CODVEND => I.CODVEND, P_CODPARC => I.CODPARC,P_CODEMP => P_CODEMP);
            END IF;
    
            V_SUMFAT:= V_FATPCR + NVL(I.FATESTIPCR,0);
            V_PTCPCR:= ROUND(NVL((V_FATPCR / NULLIF(I.FATVEN, 0)) * 100,0), CSDEC);
            V_AVPCR:= NVL(V_SUMFAT, 0) * (NVL(I.AVPCRPERC, 0) / 100);
            V_PXMETA:= ROUND(NVL(I.PXMETA, 0) * (V_PTCPCR/100) * (1+ NVL(I.PTCPCRCRESC,0) /100), CSDEC);
            V_VARPERC:= ROUND(NVL((V_PXMETA - V_SUMFAT) / NULLIF(V_SUMFAT, 0) *100, 0), CSDEC);

            -- Atualiza na tabela
            UPDATE AD_TMTFATRTVENPCR SET
                FATPCR = V_FATPCR,
                PTCPCR = V_PTCPCR,
                AVPCR = V_AVPCR,
                PXMETA = V_PXMETA,
                VPERCPCR = V_VARPERC
            WHERE CODMETA = P_CODMETA
                AND NRORESPCR = I.NRORESPCR
                AND NRORESVEN = I.NRORESVEN;
        END LOOP;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'Erro na Rotina <b>[JS_STP_CALC_RES_VEN_PCR]: </b>' || SQLERRM);
END;