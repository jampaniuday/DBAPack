SET TERMOUT OFF FEEDBACK OFF VERIFY OFF PAGES 500 LINES 200 UNDERLINE '~'

DEFINE P1=&1.

COL EXECUTIONS       FORMAT 99g999G999G999 HEAD "Execu��es"
COL DISK_READS       FORMAT 999G999G999    HEAD "Leituras|F�sicas"
COL BUFFER_GETS      FORMAT 99G999G999G999 HEAD "Leituras|L�gicas"
COL SHARABLE_MEM     FORMAT 99G999G999     HEAD "Mem�ria|Compartilhada"
COL ROWS_PROCESSED   FORMAT 99g999G999G999 HEAD "Linhas|Processadas"
COL SORTS            FORMAT 99G999G999     HEAD "Sorts"
COL USERS_OPENING    FORMAT 99G999G999     HEAD "Usu�rios|Abrindo"
COL USERS_EXECUTING  FORMAT 99G999G999     HEAD "Usu�rios|Executando"
COL CHILDS           FORMAT 99G999G999     HEAD "Vers�es|Total"
COL LOADED_VERSIONS  FORMAT 99G999G999     HEAD "Vers�es|Carregadas"
COL OPEN_VERSIONS    FORMAT 99G999G999     HEAD "Vers�es|Abertas"
COL DR_EXEC          FORMAT 99G999G999     HEAD "Leit. F�s.|/Execu��es"
COL BG_EXEC          FORMAT 9G999G999G999  HEAD "Leit. L�gica|/Execu��es"
COL PARSING_USER     FORMAT A20            HEAD "Parsing User"

COL HASH_VALUE       FORMAT 99999999999999999
COL PLAN_HASH_VALUE  FORMAT 99999999999999999

COL ADDRESS          FORMAT A20
COL OUTLINE_CATEGORY FORMAT A20

COL GET_HASH NEW_VALUE P_HASH PRINT
COL GET_ADDR NEW_VALUE P_ADDR NOPRINT
COL GET_SQLID NEW_VALUE P_SQL_ID NOPRINT
COL VERSAO NEW_VALUE P_VERSAO NOPRINT
COL QTCOPIAS NEW_VALUE P_QTCOPIAS NOPRINT
COL WHERE_CURSOR NEW_VALUE P_WHERE_CURSOR NOPRINT

DEFINE P_HASH='0'
DEFINE P_ADDR='0'
DEFINE P_QTCOPIAS='-1'
DEFINE P_VERSAO=''
DEFINE P_WHERE_CURSOR=''
DEFINE P_SQL_ID=''

SELECT DECODE( UPPER(SUBSTR( '&P1.',1,5)), '', '1=0', 'HASH=',
  'HASH_VALUE = ' || SUBSTR( '&P1.',6, LENGTH('&P1.')) || '',
  'SQL_ID = ''&P1.''' ) WHERE_CURSOR
FROM DUAL
/

SELECT HASH_VALUE GET_HASH, ADDRESS GET_ADDR, QTCOPIAS, GET_SQLID
FROM
(
  SELECT
    TO_CHAR(HASH_VALUE) HASH_VALUE, ADDRESS, SQL_ID GET_SQLID,
    OPEN_VERSIONS,
    DECODE( TRUNC( (SELECT COUNT(*) FROM GV$SQL WHERE SQL_ID = S.SQL_ID) / 100 ), 0, 0,
                   (SELECT COUNT(*) FROM GV$SQL WHERE SQL_ID = S.SQL_ID) )  QTCOPIAS
  FROM GV$SQLAREA S
  WHERE &P_WHERE_CURSOR.
  ORDER BY OPEN_VERSIONS DESC
)
WHERE ROWNUM < 2
/

SELECT DECODE( &P_QTCOPIAS., '-1', '1', '0', SUBSTR( VERSION, 1, INSTR(VERSION, '.')-1), '' ) VERSAO
FROM GV$INSTANCE
/

SET TERMOUT ON


SELECT
  ADDRESS
 ,HASH_VALUE
 ,(SELECT USERNAME FROM all_users WHERE USER_ID = PARSING_USER_ID ) PARSING_USER
 ,COUNT(*) CHILDS
 ,SUM( USERS_OPENING ) USERS_OPENING
 ,SUM( USERS_EXECUTING ) USERS_EXECUTING
FROM GV$SQL
WHERE &P_WHERE_CURSOR.
GROUP BY ADDRESS, HASH_VALUE, PARSING_USER_ID
/

SELECT
  DECODE( ADDRESS, '&P_ADDR', '* ', '  ' ) || ADDRESS ADDRESS,
  EXECUTIONS, SORTS, ROWS_PROCESSED, DISK_READS,
  ROUND(DISK_READS/DECODE(EXECUTIONS,0,1,EXECUTIONS),2) DR_EXEC,
  BUFFER_GETS, ROUND(BUFFER_GETS/DECODE(EXECUTIONS,0,1,EXECUTIONS),2) BG_EXEC
FROM GV$SQLAREA
WHERE &P_WHERE_CURSOR.
ORDER BY ADDRESS
/

REM PROMPT DEBUG HASH: &P_HASH.
REM PROMPT DEBUG ADDRESS: &P_ADDR.
REM PROMPT DEBUG VERSAO = '&P_VERSAO.' COPIAS = &p_qtcopias.
REM PROMPT DEBUG WHERE_CURSOR &P_WHERE_CURSOR.

/*
SELECT DECODE( ADDRESS, '&P_ADDR', '* ', '  ' ) || ADDRESS ADDRESS,
  USERS_OPENING, USERS_EXECUTING, VERSION_COUNT, LOADED_VERSIONS, OPEN_VERSIONS
FROM V$SQLAREA
WHERE &P_WHERE_CURSOR.
ORDER BY ADDRESS
*/


select /*+NO_MERGE(V) materialize*/ to_char(substr(sf,(level-1)*2000+1,2000)) sql_text
from (select sql_fulltext sf from v$sqlarea 
      WHERE &P_WHERE_CURSOR.
      AND ADDRESS = '&P_ADDR.'
     union all
     select sql_text from dba_hist_sqltext
     WHERE &P_WHERE_CURSOR.
     and not exists (select 1 from v$sqlarea WHERE &P_WHERE_CURSOR.)) V
connect by level<=ceil(length(sf)/2000)
UNION ALL
SELECT '/' FROM DUAL
.

SET SERVEROUT ON
PROMPT
DECLARE
  -- ESTE BLOCO SERVE PARA RECUPERAR O TEXTO DE UM SQL
  NLEN    PLS_INTEGER ;
  IDX     PLS_INTEGER := 0;
  NPOS    PLS_INTEGER := 0;
  V_TXT   VARCHAR2(32000) := '';
  V_LINHA VARCHAR2(120) := '';

  FUNCTION RESERVADA( L VARCHAR2 ) RETURN NUMBER
  IS
    TYPE T IS TABLE OF VARCHAR2(30);
    A T := T( 'WITH', 'UPDATE', 'INSERT', 'DELETE', 'SELECT', 'FROM', 'WHERE', 'GROUP BY', 'HAVING',
               'ORDER BY', 'START WITH', 'CONNECT BY', 'VALUES', 'SET' );
    P PLS_INTEGER;
  BEGIN
    RETURN 0; -- INIBE ESTA FUNCAO
    FOR I IN A.FIRST .. A.LAST LOOP
       P := INSTR( L, A(I) );
       IF P > 2 THEN
         RETURN P-1;
       END IF;
    END LOOP;
    RETURN 0;
  END;

  FUNCTION WORDBREAK( L VARCHAR2 ) RETURN NUMBER
  IS
    A VARCHAR2(40) := '.,.=.>.<.).+.-.*./.';
    N PLS_INTEGER := LENGTH( L );
  BEGIN
    -- RETURN LENGTH(L); -- INIBE ESTA FUNCAO
    IF INSTR( L, CHR(10) ) > 0 THEN
      RETURN INSTR( L, CHR(10) );
    ELSIF N < 120 THEN
      RETURN N;
    ELSE
      FOR I IN REVERSE 1 .. LENGTH(L) LOOP
        IF INSTR( A, '.'||SUBSTR( L, I, 1 )||'.' ) > 0 THEN
          RETURN I;
        END IF;
      END LOOP;
    END IF;
    RETURN N;
  END;

BEGIN

  DBMS_OUTPUT.PUT_LINE( 'Comando de SQL' );
  DBMS_OUTPUT.PUT_LINE( LPAD( '~', 120, '~' ) );

  FOR C IN
  (
    SELECT SQL_TEXT FROM GV$SQLTEXT_WITH_NEWLINES
    WHERE &P_WHERE_CURSOR.
    AND ADDRESS = '&P_ADDR.'
    ORDER BY PIECE
  )
  LOOP
    V_TXT := V_TXT || C.SQL_TEXT;
  END LOOP;

  NLEN := LENGTH( V_TXT );

  WHILE IDX < NLEN LOOP

    V_LINHA := UPPER( SUBSTR( V_TXT, IDX+1, 120 ) );

    NPOS := RESERVADA( V_LINHA );

    IF NPOS = 0 THEN
      NPOS := WORDBREAK( V_LINHA );
    END IF;

    DBMS_OUTPUT.PUT_LINE( REPLACE(SUBSTR( V_TXT, IDX+1, NPOS ), CHR(10), '' ) );
    IDX := IDX + NPOS;

  END LOOP;

  IF LENGTH( V_TXT ) > 0 THEN
    DBMS_OUTPUT.PUT_LINE( '/' );
  ELSE
    DBMS_OUTPUT.PUT_LINE( 'Comando n�o encontrado!' );
  END IF;

END;
/

SET SERVEROUT OFF

REM PROMPT DEBUG &p_hash. '&p_addr.'
PROMPT DEBUG @getplan&p_versao. &p_hash. &p_addr.

@getplan&p_versao. &p_hash. &p_addr.

ROLLBACK
/

PROMPT

SET PAGES 100 FEEDBACK 6 VERIFY ON UNDERLINE '-'

COL VERSAO CLEAR
COL QTCOPIAS CLEAR
COL GET_ADDR CLEAR
COL GET_SQLID CLEAR
COL ADDRESS CLEAR

UNDEFINE P1

UNDEFINE P_VERSAO
UNDEFINE P_QTCOPIAS
UNDEFINE P_HASH
UNDEFINE P_ADDR
UNDEFINE P_SQL_ID

