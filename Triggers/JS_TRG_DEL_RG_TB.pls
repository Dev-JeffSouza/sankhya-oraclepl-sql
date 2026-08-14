CREATE OR REPLACE TRIGGER JS_TRG_BF_DEL_RG_TB 
BEFORE DELETE ON AD_TMTFAT
FOR EACH ROW 
DECLARE
	V_SIM CHAR(1);
	V_CODUSU INT;
    V_USER  VARCHAR(30);
BEGIN
	--Busca o usuário logado
	V_CODUSU:= STP_GET_CODUSULOGADO();

	IF V_CODUSU IS NULL THEN
		RAISE_APPLICATION_ERROR(-20001,'Validação de Permissão: <b>Usuário não encontrado na sessão atual.</b>');
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
            RAISE_APPLICATION_ERROR(-20001,'Validação de Permissão: <b>Usuário não encontrodo na base de dados.</b>');
    END;

	--Verifica se o usuário tem permissão para excluir metas
	IF V_SIM = 'N' THEN
		RAISE_APPLICATION_ERROR(-20001, '<b>Usuário: ' || V_CODUSU ||' - '|| V_USER || ', não tem permissão para excluir metas.</b>');
	END IF;

END;
