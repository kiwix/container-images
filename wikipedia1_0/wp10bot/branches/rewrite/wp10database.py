# -*- coding: utf-8  -*-

#
# (C) stanlekub, 2007-2008
#
# Distributed under the terms of the MIT license.
#
# $Id$

import os
import sys
from pysqlite2 import dbapi2 as sqlite

import wikipedia
from pyuca import Collator
c = Collator(os.environ['HOME']+'/HAL/hal/trunk/allkeys.txt')


db_filename = './wp10evals.db3'

indexes_dic = {
    u'cle':             ('evaluations',     'cle'),
    u'titre':           ('evaluations',     'titre'),
    u'project':         ('evaluations',     'project'),
    u'importance':      ('evaluations',     'importance'),
    u'quality':         ('evaluations',     'quality'),
    u'cle_old':         ('old_evaluations', 'cle'),
    u'titre_old':       ('old_evaluations', 'titre'),
    u'project_old':     ('old_evaluations', 'project'),
    u'importance_old':  ('old_evaluations', 'importance'),
    u'quality_old':     ('old_evaluations', 'quality'),
    }

if os.path.exists(db_filename):
    wikipedia.output(u'DB: base de données trouvée : %s.'
                            % os.path.abspath(db_filename))
else:
    wikipedia.output(u''.ljust(80, '?'))
    rep = wikipedia.inputChoice (u"La base de données n'a pas été trouvée, "
                                    u"en créer une ?",
                                    [u'Oui', u'Non'], [u'O', u'N'], u'N')
    if rep == u'n':
        wikipedia.output(u'\03{lightred}Abandon...\03{default}')
        sys.exit()

conn = sqlite.connect(db_filename)
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master "
                "WHERE type='table' ORDER BY name")
tables = cursor.fetchall()
if not (u'evaluations',) in tables:
    wikipedia.output(u'DB: création de la table "evaluations"...')
    cursor.execute("CREATE TABLE evaluations (cle varchar(255), "
                    "titre varchar(255) not null, "
                    "project varchar(100) not null, "
                    "quality integer, importance integer, "
                    "selection05 integer, npov integer)")
if not (u'old_evaluations',) in tables:
    wikipedia.output(u'DB: création de la table "old_evaluations"...')
    cursor.execute("CREATE TABLE old_evaluations (cle varchar(255), "
                    "titre varchar(255) not null, "
                    "project varchar(100) not null, "
                    "quality integer, importance integer, "
                    "date varchar(100), diff varchar(500))")
if not (u'system',) in tables:
    wikipedia.output(u'DB: création de la table "system"...')
    cursor.execute("CREATE TABLE system (id varchar(20), value integer)")


def natsort_collate(string1, string2):
    s1 = string1.decode('utf-8').lower()
    s2 = string2.decode('utf-8').lower()
    if s1 == s2:
        return 0
    if s1 == sorted((s1, s2), key=c.sort_key)[0]:
        return -1
    return 1


class Db:
    def __init__(self):
        self._conn = sqlite.connect(db_filename, timeout=60.0)
        self._cursor = self._conn.cursor()
        self._rowcount_total = 0
        self._reset()

    def _reset(self):
        self._rowcount_last = None
        self._last_result = None

    def read(self, query, values=None):
        self._reset()
        if "natsort" in query.lower():
            self._conn.create_collation("natsort", natsort_collate)
        if values:
            assert isinstance(values, tuple), "BUG: 'values' n'est pas de " \
                                                "type 'tuple' mais %s !" \
                                                    % type(values)
            self._cursor.execute(query, values)
        else:
            self._cursor.execute(query)

    def write(self, query, values=None):
        self._reset()
        if values:
            assert isinstance(values, tuple),"BUG: 'values' n'est pas de " \
                                                "type 'tuple' mais %s !" \
                                                    % type(values)
            self._cursor.execute(query, values)
        else:
            self._cursor.execute(query)
        self._conn.commit()

    def writemany(self, query, manyvalues):
        self._reset()
        self._cursor.executemany(query, manyvalues)
        self._conn.commit()

    def fetchall(self):
        if not self._last_result:
            self._last_result = []
            self._rowcount_last = 0
            for row in self._cursor.fetchall():
                self._rowcount_last += 1
                dic = {}
                for idx, col in enumerate(self._cursor.description):
                    dic[col[0]] = row[idx]
                self._last_result.append(dic)
            self._rowcount_total += self._rowcount_last
        for row in self._last_result:
            yield row

    def fetchsome(self, start, end):
        if not self._last_result:
            self.fetchall()
        for row in self._last_result[start:end]:
            yield row

    def rowCountLast(self):
        if not self._rowcount_last:
            for row in self.fetchall():
                pass
        return self._rowcount_last

    def rowCountTotal(self):
        if not self._rowcount_last:
            self.rowCountLast()
        return self._rowcount_total

    def resetTotal(self):
        self._rowcount_total = 0

    def deleteIndexes(self, table_name):
        self.read("SELECT name FROM sqlite_master "
                    "WHERE type='index' ORDER BY name")
        indexes = list(self.fetchall())
        for index in indexes_dic:
            if indexes_dic[index][0] == table_name:
                if {'name':index,} in indexes:
                    wikipedia.output(u'DB: Suppression de l\'index "%s"...'
                                        % index)
                    sql = "DROP INDEX %s" % index
                    self.write(sql)

    def createIndexes(self, table_name):
        self.read("SELECT name FROM sqlite_master "
                    "WHERE type='index' ORDER BY name")
        indexes = list(self.fetchall())
        for index in indexes_dic:
            if indexes_dic[index][0] == table_name:
                if not {'name':index,} in indexes:
                    wikipedia.output(u'DB: création de l\'index "%s"...'
                                        % index)
                    sql = "CREATE INDEX %s ON %s(%s)" \
                                % (index, indexes_dic[index][0],
                                    indexes_dic[index][1])
                    self.write(sql)

    def close(self):
        self._cursor.close()
        self._conn.close()


def evaluationsInit(project=None):
    db = Db()
    if not project:
        db.write("DELETE FROM evaluations")
    else:
        db.write("DELETE FROM evaluations WHERE project=?", (project, ))
    db.deleteIndexes('evaluations')
    db.close()

def evaluationsFinalize(project=None):
    db = Db()
    db.createIndexes('evaluations')
    db.close()

def oldEvaluationsInit(project=None):
    db = Db()
    if not project:
        db.write("DELETE FROM old_evaluations")
    else:
        db.write("DELETE FROM old_evaluations WHERE project=?", (project, ))
    db.deleteIndexes('old_evaluations')
    db.close()

def oldEvaluationsFinalize(project=None):
    db = Db()
    db.createIndexes('old_evaluations')
    db.close()

def updateSysValue(sysid, value):
    r = getSysValue(sysid)
    db = Db()
    if r:
        db.write("UPDATE system SET value=? WHERE id=?", (value, sysid))
    else:
        db.write("INSERT INTO system (id, value) VALUES (?, ?)",
                    (sysid, value))
    db.close()

def getSysValue(sysid):
    db = Db()
    db.read("SELECT * FROM system WHERE id=?", (sysid,))
    if db.rowCountLast() == 0:
        result = None
    else:
        for row in db.fetchall():
            result = row['value']
    db.close()
    return result

def main():
    test = db()
    test.read("SELECT * FROM sqlite_master "
                "WHERE type=? or ? ORDER BY name", ('table', 'name'))
    print test.rowCountLast()
    print test.rowCountTotal()
    for result in test.fetchall():
        print
        for cle in result.keys():
            print cle+':', result[cle]
    test.read("SELECT * FROM sqlite_master "
                "WHERE type=? or ? ORDER BY name", ('table', 'name'))
    print test.rowCountTotal()

if __name__ == "__main__":
    try:
        main()
    finally:
        wikipedia.stopme()
