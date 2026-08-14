CREATE OR REPLACE PROCEDURE JS_STP_DEL_GRADE (
	P_CODUSU NUMBER,        
    P_IDSESSAO VARCHAR2,  
	P_QTDLINHAS NUMBER, 
    P_MENSAGEM OUT VARCHAR2 
) AS
	V_CONFIR		VARCHAR2(1);
	V_TITLE			VARCHAR2(100);
	V_MENSAGEM		VARCHAR2(4000);
	V_FIELD_CODMETA	NUMBER;
BEGIN
	
	IF P_QTDLINHAS > 1 THEN
        P_MENSAGEM:= '<b>Por questões de performance, é permitido a deleção de grades de uma meta por vez. Linhas selecionadas:</b> ' || TO_CHAR(P_QTDLINHAS);
        RETURN;
    END IF;

	V_FIELD_CODMETA:= ACT_INT_FIELD(P_IDSESSAO, 1, 'CODMETA');

	IF V_FIELD_CODMETA IS NULL THEN
		RAISE_APPLICATION_ERROR(-20001,'Erro: <b>A meta selecionada não foi identificada. Certifique-se de que o registro está salvo antes de limpar.</b>');
	END IF;
	
	V_TITLE:= 'Limpeza de Grades';
	V_MENSAGEM:= 'Deseja limpar (Deletar) todos os registros da Meta ' || TO_CHAR(V_FIELD_CODMETA) || '?';
	V_CONFIR:= ACT_ESCOLHER_SIMNAO(V_TITLE,V_MENSAGEM,P_IDSESSAO,1);

	IF V_CONFIR ='S' THEN
		-- Deleção 
		DELETE FROM AD_TMTFATRTVENPCR WHERE CODMETA = V_FIELD_CODMETA;
		DELETE FROM AD_TMTFATRTVENPRO WHERE CODMETA = V_FIELD_CODMETA;
		DELETE FROM AD_TMTFATRTVEN WHERE CODMETA = V_FIELD_CODMETA;
		DELETE FROM AD_TMTFATRTPRO WHERE CODMETA = V_FIELD_CODMETA;

		P_MENSAGEM:= '<b>Limpeza efetuada com Sucesso!</b>';
	ELSE
		
		P_MENSAGEM:= '<b>Operação cancelada pelo usuário.</b>';
	END IF;

END;