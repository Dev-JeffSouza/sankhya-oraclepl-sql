CREATE OR REPLACE TRIGGER JS_TRG_BF_DEL_RG_TB 
BEFORE DELETE ON AD_TMTFAT
FOR EACH ROW 
DECLARE
	V_SIM       CHAR(1);
	V_CODUSU    INT;
    V_USER      VARCHAR(30);
    V_MSG       VARCHAR2(4000);
BEGIN
	--Busca o usuário logado
	V_CODUSU:= TSIUSU_LOG_PKG.V_CODUSULOG;

	IF V_CODUSU IS NULL THEN
        V_MSG:= JS_FC_CARD_ERR_HTML5('Validação de Permissão','Usuário não encontrado na sessão atual.');
		RAISE_APPLICATION_ERROR(-20001, V_MSG);
	END IF;

    BEGIN
        SELECT 
            NVL(AD_DELMETA,'N'),
            NOMEUSU
        INTO V_SIM, V_USER
        FROM TSIUSU 
        WHERE CODUSU = V_CODUSU
            AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
             V_MSG:= JS_FC_CARD_ERR_HTML5('Validação de Permissão','Usuário não encontrodo na base de dados.');
            RAISE_APPLICATION_ERROR(-20001, V_MSG);
    END;

	--Verifica se o usuário tem permissão para excluir metas
	IF V_SIM = 'N' THEN
         V_MSG:= JS_FC_CARD_ERR_HTML5('Usuário: ' || V_CODUSU ||' - '|| V_USER,'Não tem permissão para excluir metas.');
         RAISE_APPLICATION_ERROR(-20001, V_MSG);
	END IF;
END;
