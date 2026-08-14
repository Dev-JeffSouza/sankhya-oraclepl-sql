create or replace PROCEDURE JS_STP_CALC_META_VEN (
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
                                                    -- ANOTAÇÃO: LEMBRAR DE AMARRAR O VENDEDOR QUE RECEBEU MOVIMENTAÇÃO DE OUTRO                    
                                                    -- PARA NÃO PERMITIR QUE ELE SEJA MUDADO POIS MOVINMPORT = 'S'
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
        V_DTINI:= P_DTINI;
        V_DTFIN:= P_DTFIN;
        V_CODEMP:= P_CODEMP;
        --Desvia o fluxo da Trigger
        IF P_FATGERAL IS NOT NULL AND P_FATGERALMETA IS NOT NULL THEN
            V_FATGERALANT:= P_FATGERAL;
            V_FATGERALMETA:= P_FATGERALMETA;
        ELSE
            BEGIN
                SELECT 
                    FATGERALMETA, FATGERAL
                INTO 
                    V_FATGERALMETA, V_FATGERALANT
                FROM AD_TMTFAT 
                WHERE CODMETA = P_CODMETA;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    V_FATGERALMETA:= 0;
                    V_FATGERALANT:= 0;
            END;
        END IF;

        FOR I IN (
            SELECT 
                NRORESVEN,
                CODVEND, 
                FATVEN,
                FATESTIVEN,
                MOVIMPORTVEN,
                AVVENPERC, 
                PTCVENCRESC 
                FROM AD_TMTFATRTVEN 
            WHERE CODMETA = P_CODMETA) 
        LOOP

            IF NVL(I.MOVIMPORTVEN,'N') != 'N' THEN
                V_FATVEN:= NVL(I.FATVEN, 0);
            ELSE
                V_FATVEN:= JS_FC_CALC_FAT(P_DTINI => V_DTINI, P_DTFIN => V_DTFIN, P_CODVEND => I.CODVEND, P_CODEMP => V_CODEMP);
            END IF;

            V_SUMFAT:= V_FATVEN + NVL(I.FATESTIVEN, 0);
            V_PTCVEN:= ROUND(NVL((V_SUMFAT / NULLIF(V_FATGERALANT, 0)) * 100, 0), CSDEC);
            V_AVVEN:= NVL(V_SUMFAT, 0) * (NVL(I.AVVENPERC, 0) / 100);
            V_PXMETA:= ROUND(NVL(V_FATGERALMETA, 0) * (V_PTCVEN/100) * (1 + (I.PTCVENCRESC / 100)), CSDEC);
            V_VARPERC:= ROUND(NVL((V_PXMETA - V_SUMFAT) / NULLIF(V_SUMFAT, 0) *100, 0), CSDEC);

            -- Atualiza na tabela
            UPDATE AD_TMTFATRTVEN SET
                FATVEN = V_FATVEN,
                PTCVEN = V_PTCVEN,
                AVVEN  = V_AVVEN,
                PXMETA = V_PXMETA,
                VPERCVEN = V_VARPERC
            WHERE CODMETA = P_CODMETA 
                AND NRORESVEN = I.NRORESVEN;
        END LOOP;
    END IF;

EXCEPTION
  WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'Erro na Rotina <b>[JS_STP_CALC_META_VEN]: </b>' || SQLERRM);
END;

