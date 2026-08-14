CREATE OR REPLACE TRIGGER JS_TRG_UPD_AD_TMTFATRTVEN
BEFORE UPDATE OF CODVEND ON AD_TMTFATRTVEN
FOR EACH ROW
WHEN (NVL(NEW.MOVIMPORTVEN, 'N') != 'N')
DECLARE
    V_MSG_ERRO VARCHAR2(4000);
BEGIN   
    IF :NEW.CODVEND != :OLD.CODVEND THEN
        V_MSG_ERRO := JS_FC_FORMATA_HTML5(
            P_TITULO   => 'Alteração de Vendedor não Permitida',
            P_MOTIVO   => 'Este vendedor possui movimentações financeiras que foram importadas e consolidadas de outro(s) vendedor(es).',
            P_ACAO     => 'Caso precise atualizar o vendedor, você deve excluir a importação atual ou cadastra-lo novamente.',
            P_REGISTRO => 'Vendedor Atual: ' || TO_CHAR(:OLD.CODVEND) || ' -> Novo: ' || TO_CHAR(:NEW.CODVEND)
        );

        RAISE_APPLICATION_ERROR(-20001, V_MSG_ERRO);
    END IF;
END;
