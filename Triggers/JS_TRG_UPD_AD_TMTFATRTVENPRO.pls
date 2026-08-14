CREATE OR REPLACE TRIGGER JS_TRG_UPD_AD_TMTFATRTVENPRO
BEFORE UPDATE OF CODPRODT ON AD_TMTFATRTVENPRO
FOR EACH ROW
WHEN (NVL(NEW.MOVIMPORTVEN, 'N') != 'N')
DECLARE
    V_MSG_ERRO VARCHAR2(4000);
BEGIN   
    IF :NEW.CODPRODT != :OLD.CODPRODT THEN
        V_MSG_ERRO := JS_FC_FORMATA_HTML5(
            P_TITULO   => 'Alteração de Produto não Permitida',
            P_MOTIVO   => 'Este produto possui movimentações financeiras que foram importadas e consolidadas de outro(s) vendedor(es).',
            P_ACAO     => 'Caso precise atualizar o produto, você deve excluir a importação atual ou cadastra-lo novamente.',
            P_REGISTRO => 'Produto Atual: ' || TO_CHAR(:OLD.CODPRODT) || ' -> Novo: ' || TO_CHAR(:NEW.CODPRODT)
        );

        RAISE_APPLICATION_ERROR(-20001, V_MSG_ERRO);
    END IF;
END;
