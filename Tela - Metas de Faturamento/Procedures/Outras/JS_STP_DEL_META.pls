CREATE OR REPLACE PROCEDURE JS_STP_DEL_META (  
       P_CODUSU NUMBER,           
       P_IDSESSAO VARCHAR2,    
       P_QTDLINHAS NUMBER,     
       P_MENSAGEM OUT VARCHAR2 
) AS
       V_FIELD_CODMETA      AD_TMTFAT.CODMETA%TYPE;
       V_CONFIR		VARCHAR2(1);
	V_TITLE		VARCHAR2(100);
	V_MENSAGEM		VARCHAR2(4000);
BEGIN
       IF P_QTDLINHAS = 0 THEN
              P_MENSAGEM:='<b>Selecione pelo menos um registro na grade!</b>';   
              RETURN; 
       END IF;

       V_TITLE:= 'Exclusão de Metas';
	V_MENSAGEM:= '<b>Deseja Deletar todos os registros da(s) Meta(s) Selecionada(s) ?</b>';
	V_CONFIR:= ACT_ESCOLHER_SIMNAO(V_TITLE,V_MENSAGEM,P_IDSESSAO,1);

       IF V_CONFIR = 'S' THEN
              FOR I IN 1..P_QTDLINHAS 
              LOOP                    
                     V_FIELD_CODMETA:= ACT_INT_FIELD(P_IDSESSAO,I, 'CODMETA');
                     
                     DELETE FROM AD_TMTFATRTVENPCR WHERE CODMETA = V_FIELD_CODMETA;
                     DELETE FROM AD_TMTFATRTVENPRO WHERE CODMETA = V_FIELD_CODMETA;
                     DELETE FROM AD_TMTFATRTVEN WHERE CODMETA = V_FIELD_CODMETA;
                     DELETE FROM AD_TMTFATRTPRO WHERE CODMETA = V_FIELD_CODMETA;
                     DELETE FROM AD_TMTFAT WHERE CODMETA = V_FIELD_CODMETA;
              END LOOP;

              P_MENSAGEM:= 'Registros de Metas excluídos com Sucesso! Total Selecionado: '|| P_QTDLINHAS;
       ELSE
              P_MENSAGEM:= 'Operação Cancelada pelo Usuário.';
       END IF;

       
END;

