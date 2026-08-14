CREATE OR REPLACE PROCEDURE JS_STP_UPT_META_PROD (
    P_CODUSU NUMBER,        
    P_IDSESSAO VARCHAR2,   
    P_QTDLINHAS NUMBER,     
    P_MENSAGEM OUT VARCHAR2 
) AS
    V_PXMETA_TOTAL   AD_TMTFAT.FATGERALMETA%TYPE; 
    V_CODMETA        AD_TMTFAT.CODMETA%TYPE;
    V_AVGERALPERC    AD_TMTFAT.AVGERALPERC%TYPE;
    V_MSG_ERRO VARCHAR2(4000);
BEGIN
    BEGIN
        V_CODMETA:= ACT_INT_FIELD(P_IDSESSAO, 1,'CODMETA');
        V_AVGERALPERC:= GET_TSIPAR_NUMERO('AVGERALPERC');

        IF V_CODMETA IS NULL THEN
            V_MSG_ERRO:= JS_FC_FORMATA_HTML5(
                    P_TITULO => 'Erro de Identificação da Meta',
                    P_MOTIVO => 'Não foi possível identificar o código da meta no contexto atual.',
                    P_ACAO   => 'Verifique se o produto já foi cadastrado na meta.'
                );
            P_MENSAGEM:= V_MSG_ERRO;
            RETURN;
        END IF;
    
        SELECT SUM(PRO.PXMETA)
        INTO V_PXMETA_TOTAL
        FROM AD_TMTFATRTPRO PRO
        WHERE PRO.CODMETA = V_CODMETA;

        V_AVGERALPERC:= NVL(V_PXMETA_TOTAL * (V_AVGERALPERC/100), 0);
    
        UPDATE AD_TMTFAT SET  
            AVGERAL = V_AVGERALPERC,
            FATGERALCRESC = 0,
            DHALTER = SYSDATE, 
            CODUSU = P_CODUSU,
            FATGERALMETA = V_PXMETA_TOTAL
        WHERE CODMETA = V_CODMETA;

        IF SQL%NOTFOUND THEN
            P_MENSAGEM:= 'Nenhuma ação realizada.';
            RETURN;
        END IF;

        P_MENSAGEM:= 'Meta atualizada com sucesso!';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_PXMETA_TOTAL := 0;
        WHEN OTHERS THEN
            RAISE;    
    END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002,'<b>Erro:</b> Não foi possível recalcular a meta de faturamento.' || SQLERRM);
END;