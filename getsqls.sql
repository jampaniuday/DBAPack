SET TERMOUT OFF FEEDBACK OFF VERIFY OFF PAGES 500 LINES 200 UNDERLINE '~'

DEFINE P1=&1.
DEFINE P_HASH='0'
DEFINE P_ADDR='0'
DEFINE P_CHILD_ADDR='0'
DEFINE P_QTCOPIAS='-1'
DEFINE P_VERSAO=''
DEFINE P_WHERE_CURSOR=''
DEFINE P_SQL_ID=''
DEFINE P_SQL_PATCH=''
DEFINE P_SQL_PROFILE=''
DEFINE P_SQL_PLAN_BASELINE=''
DEFINE P_OUTLINE_CATEGORY=''

@detalhesql &P1 true

SET VERIFY OFF FEED OFF

REM @fillplan&p_versao. &p_hash. &p_addr. &p_child_num.
REM @do.expplan.sql &p_hash.

ROLLBACK;

PROMPT

UNDEFINE P_SQL_ID P_HASH P_ADDR P_VERSAO

SET PAGES 100 FEEDBACK 6 VERIFY ON UNDERLINE '-'

