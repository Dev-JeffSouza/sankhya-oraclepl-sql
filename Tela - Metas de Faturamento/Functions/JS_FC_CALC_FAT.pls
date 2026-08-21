CREATE OR REPLACE FUNCTION JS_FC_CALC_FAT (
    P_DTINI     DATE,
    P_DTFIN     DATE,
    P_CODPROD   INT DEFAULT NULL,
    P_CODVEND   INT DEFAULT NULL,
    P_CODPARC   INT DEFAULT NULL,
    P_CODEMP    INT DEFAULT NULL,
    P_ITENEG    VARCHAR2 DEFAULT NULL          
) RETURN NUMBER AS
    V_VLRFAT NUMBER;
    V_TOPS VARCHAR(4000);
BEGIN
    -- Validando os parâmetros do chamador
    IF P_DTINI IS NULL OR P_DTFIN IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'O intervalo de datas é obrigatório!');
    END IF;

    V_TOPS:= ';' || REPLACE(GET_TSIPAR_TEXTO('TOPSCALCFAT'), ' ', '') || ';';

    IF P_CODPROD IS NOT NULL THEN
        IF NVL(P_ITENEG,'N') = 'S' THEN 
            SELECT NVL(SUM(CASE 
                        WHEN CAB.TIPMOV = 'V' THEN ITE.QTDNEG
                        ELSE -ITE.QTDNEG 
                      END), 0)
            INTO V_VLRFAT
            FROM TGFCAB CAB
            JOIN TGFITE ITE ON ITE.NUNOTA = CAB.NUNOTA
            WHERE CAB.DTMOV BETWEEN P_DTINI AND P_DTFIN
                AND CAB.STATUSNOTA = 'L'
                AND CAB.TIPMOV IN ('V','D')
                AND V_TOPS LIKE '%;' || TO_CHAR(CAB.CODTIPOPER) || ';%'
                AND ITE.CODPROD = P_CODPROD
                AND CAB.CODEMP = P_CODEMP;
        ELSE
            SELECT NVL(SUM(
                CASE --Rateio de descontos distribuidos proporcionalmente 
                    WHEN CAB.TIPMOV = 'V' THEN  
                        (ITE.VLRTOT - NVL(ITE.VLRDESC, 0) - 
                        ((NVL(CAB.VLRDESCTOT, 0) + NVL(CAB.VLRDESCPARCERIA, 0)) * 
                        (ITE.VLRTOT / NULLIF(CAB.VLRNOTA, 0))))
                    ELSE 
                        -(ITE.VLRTOT - NVL(ITE.VLRDESC, 0) - 
                        ((NVL(CAB.VLRDESCTOT, 0) + NVL(CAB.VLRDESCPARCERIA, 0)) * 
                        (ITE.VLRTOT / NULLIF(CAB.VLRNOTA, 0))))
                END
            ), 0)
            INTO V_VLRFAT
            FROM TGFCAB CAB
            JOIN TGFITE ITE ON ITE.NUNOTA = CAB.NUNOTA
            WHERE CAB.DTMOV BETWEEN P_DTINI AND P_DTFIN
                AND CAB.STATUSNOTA = 'L'
                AND CAB.TIPMOV IN ('V','D')
                AND V_TOPS LIKE '%;' || TO_CHAR(CAB.CODTIPOPER) || ';%'
                AND ITE.CODPROD = P_CODPROD
                AND (P_CODVEND IS NULL OR CAB.CODVEND = P_CODVEND)
                AND (P_CODEMP IS NULL OR CAB.CODEMP = P_CODEMP);
        END IF;
    ELSE
        SELECT NVL(SUM(CASE 
                        WHEN CAB.TIPMOV = 'V' THEN CAB.VLRNOTA 
                        ELSE -CAB.VLRNOTA 
                      END), 0)
        INTO V_VLRFAT
        FROM TGFCAB CAB
        WHERE CAB.DTMOV BETWEEN P_DTINI AND P_DTFIN
            AND CAB.STATUSNOTA = 'L'
            AND CAB.TIPMOV IN ('V','D')
            AND V_TOPS LIKE '%;' || TO_CHAR(CAB.CODTIPOPER) || ';%'
            AND (P_CODVEND IS NULL OR CAB.CODVEND = P_CODVEND)
            AND (P_CODPARC IS NULL OR CAB.CODPARC = P_CODPARC)
            AND (P_CODEMP IS NULL OR CAB.CODEMP = P_CODEMP);
    END IF;

    RETURN V_VLRFAT;
EXCEPTION
    WHEN OTHERS THEN
        RETURN -1; --Indicador de erro
END;
