-- Pas 1 Creare tablespace si user
-- Creeaza tablespace pentru date
CREATE TABLESPACE pontaj_data DATAFILE 'pontaj_data.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M;
-- Creeaza tablespace pentru indexi
CREATE TABLESPACE pontaj_index DATAFILE 'pontaj_index.dbf' SIZE 50M AUTOEXTEND ON NEXT 5M;
-- Creeaza utilizatorul care va lucra la proiect (in cazul meu polina)
CREATE USER polina IDENTIFIED BY pontaj_pass DEFAULT TABLESPACE pontaj_data TEMPORARY TABLESPACE temp;
-- Acorda drepturi de lucru
GRANT CONNECT, RESOURCE TO polina;
-- Permite acces complet la tablespece-uri 
ALTER USER polina QUOTA UNLIMITED ON pontaj_data;
ALTER USER polina QUOTA UNLIMITED ON pontaj_index;


-- Pas 2 :Crearea tabelelor si stergerea acestora 
-- Baza de date pontaj gestioneaza activitatea angajatilor in proiecte IT:
-- Contine 7 tabele: clients, projects, employees, employees_projects, tasks, work_sessions si approvals.
-- Clientii lanseaza proiecte, angajatii primesc taskuri, iar sesiunile de lucru sunt inregistrate si aprobate
-- Structura include relatii one-to-many (clienti–proiecte, angajati–taskuri) si many-to-many (angajati–proiecte)
-- Sunt definite constrangeri de integritate, valori JSON, comentarii, triggeri si validari automate

-- Stergerea în ordine corectă (copii-parinti)
DROP TABLE approvals CASCADE CONSTRAINTS;
DROP TABLE work_sessions CASCADE CONSTRAINTS;
DROP TABLE tasks CASCADE CONSTRAINTS;
DROP TABLE employees_projects CASCADE CONSTRAINTS;
DROP TABLE projects CASCADE CONSTRAINTS;
DROP TABLE clients CASCADE CONSTRAINTS;
DROP TABLE employees CASCADE CONSTRAINTS;

-- TABEL 1: CLIENTS (relatii ONE-TO-MANY cu PROJECTS)
CREATE TABLE clients (
    client_id NUMBER PRIMARY KEY,
    client_name VARCHAR2(100) NOT NULL,
    contact_number NUMBER(10),
    industry VARCHAR2(100)
) TABLESPACE pontaj_data;
COMMENT ON TABLE polina.clients IS 'Tabel cu informatii despre clientii care beneficiaza de proiecte IT';
COMMENT ON COLUMN polina.clients.client_id IS 'Cheie primara. ID unic al clientului';
COMMENT ON COLUMN polina.clients.client_name IS 'Numele complet al companiei client';
COMMENT ON COLUMN polina.clients.contact_number IS 'Numarul de telefon de contact al clientului (10 cifre)';
COMMENT ON COLUMN polina.clients.industry IS 'Industria in care activeaza clientul';

-- TABEL 2: EMPLOYEES (relatii ONE-TO-MANY cu TASKS, WORK_SESSIONS, APPROVALS)
CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    role VARCHAR2(50),
    hire_date DATE DEFAULT SYSDATE,
    programming_skills_json CLOB, -- limbaje de programare în format JSON
    CHECK (programming_skills_json IS JSON)
) TABLESPACE pontaj_data;
COMMENT ON TABLE polina.employees IS 'Tabel cu toti angajatii si managerii sistemului';
COMMENT ON COLUMN polina.employees.employee_id IS 'Cheie primara. ID unic al angajatului';
COMMENT ON COLUMN polina.employees.name IS 'Numele angajatului';
COMMENT ON COLUMN polina.employees.email IS 'Adresa de email (unica) a angajatului';
COMMENT ON COLUMN polina.employees.role IS 'Rolul in cadrul companiei';
COMMENT ON COLUMN polina.employees.hire_date IS 'Data angajarii in cadrul organizatiei';
COMMENT ON COLUMN polina.employees.programming_skills_json IS 'Lista in format JSON a limbajelor de programare cunoscute de angajat';

-- Crearea unei noi coloane manager_id pt a efectua selectia ierarhica
ALTER TABLE employees ADD (manager_id NUMBER);
-- adaugarea constrangeri
ALTER TABLE employees
ADD CONSTRAINT fk_manager
FOREIGN KEY (manager_id)
REFERENCES employees(employee_id);
--  Adaugarea unei constrangeri care interzice ca cineva să fie propriul manager
ALTER TABLE employees
ADD CONSTRAINT chk_self_manager
CHECK (employee_id != manager_id);

-- TABEL 3: PROJECTS (relație MANY-TO-MANY cu EMPLOYESS)
CREATE TABLE projects (
    project_id NUMBER PRIMARY KEY,
    project_name VARCHAR2(100) NOT NULL,
    client_id NUMBER NOT NULL,
    deadline DATE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
) TABLESPACE pontaj_data;
COMMENT ON TABLE polina.projects IS 'Tabel cu proiecte active in care lucreaza utilizatorii';
COMMENT ON COLUMN polina.projects.project_id IS 'Cheie primara. ID unic al proiectului';
COMMENT ON COLUMN polina.projects.project_name IS 'Numele proiectului';
COMMENT ON COLUMN polina.projects.client_id IS 'Cheie straina catre clients.client_id (clientul care a comandat proiectul)';
COMMENT ON COLUMN polina.projects.deadline IS 'Termenul limita al proiectului';


-- TABEL 4: employees_projects (relatie MANY-TO-MANY între EMPLOYEES Si PROJECTS)
CREATE TABLE employees_projects (
    employee_id NUMBER NOT NULL,
    project_id NUMBER NOT NULL,
    assigned_date DATE DEFAULT SYSDATE,
    role_in_project VARCHAR2(50),
    PRIMARY KEY (employee_id, project_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  FOREIGN KEY (project_id) REFERENCES projects(project_id)
) TABLESPACE pontaj_data;

COMMENT ON TABLE polina.employees_projects IS 'Tabel many-to-many intre employees si projects';
COMMENT ON COLUMN polina.employees_projects.employee_id IS 'Cheie straina catre employees.employee_id';
COMMENT ON COLUMN polina.employees_projects.project_id IS 'Cheie straina catre projects.project_id';
COMMENT ON COLUMN polina.employees_projects.assigned_date IS 'Data la care angajatul a fost alocat in proiect';
COMMENT ON COLUMN polina.employees_projects.role_in_project IS 'Rolul angajatului in proiect (ex: developer)';


-- TABEL 5: TASKS (relatii ONE-TO-MANY cu PROJECTS si employees)
CREATE TABLE tasks (
    task_id NUMBER PRIMARY KEY,
    project_id NUMBER NOT NULL,
    assigned_to NUMBER NOT NULL,
    status VARCHAR2(20) DEFAULT 'Open',
    priority VARCHAR2(10),
    CHECK (priority IN ('Low', 'Medium', 'High')),
    FOREIGN KEY (project_id) REFERENCES projects(project_id),
    FOREIGN KEY (assigned_to) REFERENCES employees(employee_id)
)TABLESPACE pontaj_data;


COMMENT ON TABLE polina.tasks IS 'Task-uri asignate utilizatorilor pentru proiecte';
COMMENT ON COLUMN polina.tasks.task_id IS 'Cheie primara. ID unic al task-ului';
COMMENT ON COLUMN polina.tasks.project_id IS 'Cheie straina catre projects.project_id';
COMMENT ON COLUMN polina.tasks.assigned_to IS 'Cheie straina catre users.user_id. Cine executa taskul';
COMMENT ON COLUMN polina.tasks.status IS 'Status curent al taskului )';
COMMENT ON COLUMN polina.tasks.priority IS 'Nivel de prioritate: Low, Medium, High';

-- TABEL 6: WORK_SESSIONS (relatii ONE-TO-MANY cu employees si TASKS)
-- am ales ca nr maxim de ore lucrate sa fie 12
CREATE TABLE work_sessions (
    session_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    task_id NUMBER,
    work_date DATE DEFAULT TRUNC(SYSDATE), -- doar data fără ora
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    CHECK (start_time < end_time),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    FOREIGN KEY (task_id) REFERENCES tasks(task_id)
) TABLESPACE pontaj_data;
--Verificarea orelor lucrate în funcție de statutul taskului
CREATE OR REPLACE TRIGGER trg_check_task_status_before_work
BEFORE INSERT OR UPDATE ON work_sessions
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT status INTO v_status
    FROM tasks
    WHERE task_id = :NEW.task_id;
    IF v_status = 'Closed' THEN
        RAISE_APPLICATION_ERROR(-20010, 'Nu se pot adauga ore pe un task deja inchis.');
    END IF;
END;
/

COMMENT ON TABLE polina.work_sessions IS 'Pontaje zilnice care înregistrează activitatea utilizatorilor pe taskuri';
COMMENT ON COLUMN polina.work_sessions.session_id IS 'ID unic pentru fiecare sesiune de lucru (cheie primară)';
COMMENT ON COLUMN polina.work_sessions.employee_id IS 'ID-ul utilizatorului care a efectuat sesiunea de lucru (cheie străină către employees.employee_id)';
COMMENT ON COLUMN polina.work_sessions.task_id IS 'ID-ul taskului pe care s-a lucrat (cheie straina catre tasks.task_id)';
COMMENT ON COLUMN polina.work_sessions.work_date IS 'Data calendaristică a zilei de lucru (fara ora)';
-- Testarea constrangerii de la check 
BEGIN
  INSERT INTO work_sessions (
    session_id, employee_id, task_id, work_date, start_time, end_time
  ) VALUES (
    99990, 1, 1, TO_DATE('2025-06-08', 'YYYY-MM-DD'),
    TO_TIMESTAMP('10-JUN-2025 18:00:00', 'DD-MON-YYYY HH24:MI:SS'),
    TO_TIMESTAMP('10-JUN-2025 09:00:00', 'DD-MON-YYYY HH24:MI:SS')  -- start > end → invalid
  );
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Eroare așteptată: ' || SQLERRM);
    ROLLBACK;
END;
/
SELECT * FROM work_sessions WHERE session_id = 99990;-- se verifica da s-a introdus  valoarea invalida
-- Am obtinut la DBMS output Eroare așteptată: ORA-02290: check constraint (POLINA.SYS_C009057) violated ceea ce denota ca constragerea a functionat 

-- TABEL 7: APPROVALS (relatie ONE-TO-ONE cu WORK_SESSIONS, aprobare data de manager din employees)
CREATE TABLE approvals (
    approval_id NUMBER PRIMARY KEY,
    session_id NUMBER NOT NULL,
    approved_by NUMBER NOT NULL,
    approval_status VARCHAR2(20),
    approval_date DATE DEFAULT SYSDATE,
    CHECK (approval_status IN ('pending', 'approved', 'rejected')),
    FOREIGN KEY (session_id) REFERENCES work_sessions(session_id),
    FOREIGN KEY (approved_by) REFERENCES employees(employee_id)
)TABLESPACE pontaj_data;
COMMENT ON TABLE polina.approvals IS 'Tabel cu aprobari pentru fiecare sesiune de lucru';
COMMENT ON COLUMN polina.approvals.approval_id IS 'Cheie primara. ID unic al aprobarii';
COMMENT ON COLUMN polina.approvals.session_id IS 'Cheie straina catre work_sessions.session_id';
COMMENT ON COLUMN polina.approvals.approved_by IS 'Cheie straina catre employees.employee_id (manager)';
COMMENT ON COLUMN polina.approvals.approval_status IS 'Statusul aprobarii: pending, approved, rejected';
COMMENT ON COLUMN polina.approvals.approval_date IS 'Data in care a fost aprobata sesiunea';
--Trigger 
-- Scopul acestui trigger este de a  verifica daca managerul care aproba o sesiune de lucru este alocat în proiectul corespunzator si
-- daca data aprobarii nu este anterioara datei la care managerul a fost alocat în acel proiect.
CREATE OR REPLACE TRIGGER trg_check_approval_project
BEFORE INSERT OR UPDATE ON approvals
FOR EACH ROW
DECLARE
  v_project_id tasks.project_id%TYPE;
  v_assigned_date employees_projects.assigned_date%TYPE;
BEGIN
  SELECT t.project_id
  INTO v_project_id
  FROM work_sessions ws
  JOIN tasks t ON ws.task_id = t.task_id
  WHERE ws.session_id = :NEW.session_id;
  -- se verifica daca managerul este alocat în acel proiect
  SELECT assigned_date
  INTO v_assigned_date
  FROM employees_projects
  WHERE employee_id = :NEW.approved_by
    AND project_id = v_project_id;
  -- se verifica daca approval_date nu este  mai veche decât data alocării
  IF :NEW.approval_date < v_assigned_date THEN
    RAISE_APPLICATION_ERROR(-20002, 'Aprobarea nu poate avea loc înainte ca managerul să fie alocat în proiect.');
  END IF;
-- controlul erorii 
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001, 'Managerul care aproba nu este alocat în proiectul corespunzator sesiunii.');
END;
/


 
-- Popularea tabebelor 


-- Populare manuala tabela EMPLOYEE
-- Ultima coloana, adica coloana manager_id, este setata cu valoare NULL pentru ca este o coloana adaugata ulterior prin ALTER TABLE, fara valoare implicita
-- In momentul inserarii initiale, structura ierarhica nu era definita. Valoarea manager_id va fi actualizata ulterior prin comenzi UPDATE, in functie de organigrama firmei.
INSERT INTO employees VALUES (1, 'Andrei Ionescu', 'andrei.ionescu@example.com', 'Project Manager', SYSDATE, '{"skills": ["Planning", "Team Management", "Budgeting"]}', NULL);
INSERT INTO employees VALUES (2, 'Ioana Popescu', 'ioana.popescu@example.com', 'Senior Business Analyst', SYSDATE, '{"skills": ["UML", "Requirements Analysis", "Stakeholder Communication"]}', NULL);
INSERT INTO employees VALUES (3, 'Mihai Georgescu', 'mihai.georgescu@example.com', 'Architect/Tech Lead', SYSDATE, '{"skills": ["System Design", "Java", "Microservices"]}', NULL);
INSERT INTO employees VALUES (4, 'Adela Enache', 'adela.enache@example.com', 'QA Lead', SYSDATE, '{"skills": ["Test Strategy", "Automation", "Leadership"]}', NULL);
INSERT INTO employees VALUES (5, 'Diana Radu', 'diana.radu@example.com', 'Product Owner', SYSDATE, '{"skills": ["Backlog Management", "Agile", "Communication"]}', NULL);
INSERT INTO employees VALUES (6, 'Robert Marinescu', 'robert.marinescu@example.com', 'Scrum Master', SYSDATE, '{"skills": ["Scrum", "Agile Facilitation", "Conflict Resolution"]}', NULL);
INSERT INTO employees VALUES (7, 'Elena Dumitru', 'elena.dumitru@example.com', 'UI/UX Designer', SYSDATE, '{"skills": ["Figma", "User Research", "Prototyping"]}', NULL);
INSERT INTO employees VALUES (8, 'Cristian Pavel', 'cristian.pavel@example.com', 'Developer', SYSDATE, '{"skills": ["Python", "React", "SQL"]}', NULL);
INSERT INTO employees VALUES (9, 'Vlad Iliescu', 'vlad.iliescu@example.com', 'QA Engineer', SYSDATE, '{"skills": ["Selenium", "Postman", "JUnit"]}', NULL);
INSERT INTO employees VALUES (10, 'Sorina Mihalache', 'sorina.mihalache@example.com', 'Technical Lead', SYSDATE, '{"skills": ["CI/CD", "Architecture", "Mentoring"]}', NULL);
INSERT INTO employees VALUES (11, 'Radu Anton', 'radu.anton@example.com', 'DevOps Engineer', SYSDATE, '{"skills": ["Docker", "Kubernetes", "Terraform"]}', NULL);
INSERT INTO employees VALUES (12, 'Anca Toma', 'anca.toma@example.com', 'Test Manager', SYSDATE, '{"skills": ["Test Planning", "Defect Tracking", "Risk Management"]}', NULL);
INSERT INTO employees VALUES (13, 'Dan Vasilescu', 'dan.vasilescu@example.com', 'Support/Operations Team', SYSDATE, '{"skills": ["Monitoring", "Troubleshooting", "Linux"]}', NULL);
INSERT INTO employees VALUES (14, 'Simona Neagu', 'simona.neagu@example.com', 'Manager', SYSDATE, '{"skills": ["Strategic Planning", "Reporting", "Team Oversight"]}', NULL);
INSERT INTO employees VALUES (15, 'Alex Popa', 'alex.popa@example.com', 'DevOps Engineer', SYSDATE, '{"skills": ["Docker", "Kubernetes", "Terraform"]}', NULL);
INSERT INTO employees VALUES (16, 'Valentina Butnariu', 'valentina.butnariu@example.com', 'Test Manager', SYSDATE, '{"skills": ["Test Planning", "Defect Tracking", "Risk Management"]}', NULL);
INSERT INTO employees VALUES (17, 'Ion Cojocaru', 'ion.cojocaru@example.com', 'Support/Operations Team', SYSDATE, '{"skills": ["Monitoring", "Troubleshooting", "Linux"]}', NULL);
INSERT INTO employees VALUES (18, 'Natalia Cotaga', 'natalia.cotaga@example.com', 'Project Manager', SYSDATE, '{"skills": ["Planning", "Team Management", "Budgeting"]}', NULL);

-- Managerul de top
--Definirea structurii ierarhice între angajați: 
-- Simona este managerul de top, 
-- Andrei și Natalia sunt Project Managers în subordinea ei,iar restul angajaților sunt împărțiți în echipele lor.
UPDATE employees SET manager_id = NULL WHERE employee_id = 14;
UPDATE employees SET manager_id = 14 WHERE employee_id IN (1, 18);
UPDATE employees SET manager_id = 1 WHERE employee_id IN (2, 3, 4, 5, 6, 7, 8, 9);
UPDATE employees SET manager_id = 18 WHERE employee_id IN (10, 11, 12, 13, 15, 16, 17);


-- Populare manuala tabela  clienti 
INSERT INTO clients VALUES (1, 'EMAG',         723456789, 'Retail');
INSERT INTO clients VALUES (2, 'Bitdefender',  726543210, 'IT Services');
INSERT INTO clients VALUES (3, 'Petrom',       721234567, 'Energy');
INSERT INTO clients VALUES (4, 'UiPath',       722223333, 'Automation');
INSERT INTO clients VALUES (5, 'BCR',          723334444, 'Finance');
INSERT INTO clients VALUES (6, 'Romgaz',       724445555, 'Energy');
INSERT INTO clients VALUES (7, 'Dedeman',      725556666, 'Retail');
INSERT INTO clients VALUES (8, 'MedLife',      726667777, 'Healthcare');
INSERT INTO clients VALUES (9, 'Orange',       727778888, 'Telecom');
INSERT INTO clients VALUES (10, 'StarTech Team', 728889999, 'IT Services');

-- Populare automata a tabelei projects unde un lcient poate avea maxim 3 trei proiecte diferite 
DECLARE
  v_id NUMBER := 1;
  v_client_id NUMBER;
  v_count NUMBER;
BEGIN
  WHILE v_id <= 20 LOOP
    v_client_id := TRUNC(DBMS_RANDOM.VALUE(1, 11)); -- client_id între 1 și 10 (deorece in bd vor fi maxim 10 cleinti)
    -- se verifica cate proiecte are deja clientul ales
    SELECT COUNT(*) INTO v_count
    FROM projects
    WHERE client_id = v_client_id;
    -- Daca are mai putin de 3 proiecte, se face inserarea
    IF v_count < 3 THEN
      INSERT INTO projects (
        project_id,
        project_name,
        client_id,
        deadline
      ) VALUES (
        v_id,
        'Proiect_' || DBMS_RANDOM.STRING('U', 4),
        v_client_id,
        SYSDATE + TRUNC(DBMS_RANDOM.VALUE(30, 365))
      );
      v_id := v_id + 1; 
    END IF;
  END LOOP;
END;
/

-- Popularea automata a tabelei employyes_project

--Fiecare angajat va lucra la proiecte (nu va exista angajta care nu este alocat unui proiect )
--Fiecare angajat poate participa la maxim doua proiecte concomitent
--Numarul total de alocari este limitat la 28, corespunzător celor 14 angajați × 2 proiecte per angajat
--Rolul angajatului in cadrul proiectului este preluat automat din tabela employees si nu este generat aleatoriu
--In cazul in care combinatia (employee_id, project_id) exista deja, inserarea este controlata prin DUP_VAL_ON_INDEX
-- Vor exista angajati care nu sunt alocati pe nici un proiect 

DECLARE
  v_emp_id NUMBER;
  v_proj_id NUMBER;
  v_role employees.role%TYPE;
  v_count NUMBER;
  v_total NUMBER := 0;
BEGIN
  WHILE v_total < 28 LOOP -- 14 angajati × 2 proiecte = 28 alocari maxime 
    v_emp_id := TRUNC(DBMS_RANDOM.VALUE(1, 19)); -- 18 angajati
    v_proj_id := TRUNC(DBMS_RANDOM.VALUE(1, 21)); -- 20 proiecte
    -- se verifica cate proiecte are deja angajatul
    SELECT COUNT(*) INTO v_count
    FROM employees_projects
    WHERE employee_id = v_emp_id;
    -- dacă are sub 2 proiecte
    IF v_count < 2 THEN
      BEGIN
        SELECT role INTO v_role FROM employees WHERE employee_id = v_emp_id;
        INSERT INTO employees_projects (
          employee_id,
          project_id,
          assigned_date,
          role_in_project
        ) VALUES (
          v_emp_id,
          v_proj_id,
          SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 100)),
          v_role
        );
        v_total := v_total + 1;
-- controlul eroirii asupra combinatiei de (employee_id, project_id) deja existente
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          NULL; 
      END;
    END IF;
  END LOOP;
END;
/

-- Popularea automata a tabelei tasks
--Se populeaza automat tabela tasks cu 100 de sarcini alocate doar angajatilor care lucrează deja in proiecte (conform tabelului employees_projects)
DECLARE
  v_id NUMBER := 1;
  v_emp_id NUMBER;
  v_proj_id NUMBER;
  v_status VARCHAR2(20);
  v_priority VARCHAR2(10);
BEGIN
  WHILE v_id <= 100 LOOP
    -- se alege o combinație (employee_id, project_id) deja existenta din employees_projects
    SELECT employee_id, project_id
    INTO v_emp_id, v_proj_id
    FROM (
      SELECT employee_id, project_id
      FROM employees_projects
      ORDER BY DBMS_RANDOM.VALUE
    )
    WHERE ROWNUM = 1;
    -- Status aleator
    v_status := CASE TRUNC(DBMS_RANDOM.VALUE(1, 4))
                  WHEN 1 THEN 'Open'
                  WHEN 2 THEN 'In Progress'
                  WHEN 3 THEN 'Completed'
                END;
    -- Prioritate aleatorie
    v_priority := CASE TRUNC(DBMS_RANDOM.VALUE(1, 4))
                    WHEN 1 THEN 'Low'
                    WHEN 2 THEN 'Medium'
                    WHEN 3 THEN 'High'
                  END;
    INSERT INTO tasks (
      task_id,
      project_id,
      assigned_to,
      status,
      priority
    ) VALUES (
      v_id,
      v_proj_id,
      v_emp_id,
      v_status,
      v_priority
    );
    v_id := v_id + 1;
  END LOOP;
END;
/

-- Tbaela work_session (pontaj)
DECLARE
  v_id NUMBER := 1;
  v_emp_id NUMBER;
  v_task_id NUMBER;
  v_date DATE;
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_diff NUMBER;
BEGIN
  WHILE v_id <= 100 LOOP
    -- Alege aleator un task existent cu angajatul care îl are alocat
    SELECT assigned_to, task_id
    INTO v_emp_id, v_task_id
    FROM (
      SELECT assigned_to, task_id
      FROM tasks
      ORDER BY DBMS_RANDOM.VALUE
    )
    WHERE ROWNUM = 1;
    -- Data lucrarii: aleator între ultimele 30 zile
    v_date := TRUNC(SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 30)));
    -- Ora de început: între 08:00-18:00
    v_start := TO_TIMESTAMP(v_date || ' ' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(8, 19)), '00') || ':00:00', 'YYYY-MM-DD HH24:MI:SS');
    -- Durată între 1 și 8 ore
    v_diff := TRUNC(DBMS_RANDOM.VALUE(1, 9));
    v_end := v_start + v_diff / 24;
    INSERT INTO work_sessions (
      session_id,
      employee_id,
      task_id,
      work_date,
      start_time,
      end_time
    ) VALUES (
      v_id,
      v_emp_id,
      v_task_id,
      v_date,
      v_start,
      v_end
    );
    v_id := v_id + 1;
  END LOOP;
END;
/

-- Populare automata tabelei approvals 
DECLARE
  v_id NUMBER := 1;
  v_manager_id NUMBER;
  v_status VARCHAR2(20);
  v_date DATE;
BEGIN
  FOR rec IN (
    SELECT 
      ws.session_id,
      t.project_id,
      ep.employee_id AS manager_id,
      ep.assigned_date
    FROM work_sessions ws
    INNER JOIN tasks t ON ws.task_id = t.task_id
    INNER JOIN employees_projects ep ON ep.project_id = t.project_id
    INNER JOIN employees e ON e.employee_id = ep.employee_id
    WHERE e.role = 'Manager'
  ) LOOP
    -- status aleator
    v_status := CASE TRUNC(DBMS_RANDOM.VALUE(1, 4))
                  WHEN 1 THEN 'pending'
                  WHEN 2 THEN 'approved'
                  WHEN 3 THEN 'rejected'
                END;
    -- data aprobării: după ce managerul a fost alocat
    v_date := rec.assigned_date + TRUNC(DBMS_RANDOM.VALUE(0, 5));
    INSERT INTO approvals (
      approval_id,
      session_id,
      approved_by,
      approval_status,
      approval_date
    ) VALUES (
      v_id,
      rec.session_id,
      rec.manager_id,
      v_status,
      v_date
    );
    v_id := v_id + 1;
  END LOOP;
END;
/

-- Crearea indexurilor
CREATE INDEX idx_ws_emp_date ON work_sessions(employee_id, work_date);
CREATE INDEX idx_ws_task ON work_sessions(task_id);
CREATE INDEX idx_ws_workdate ON work_sessions(work_date);
CREATE INDEX idx_ws_start_end ON work_sessions(start_time, end_time);
CREATE INDEX idx_emp_skills_json ON employees(programming_skills_json)
INDEXTYPE IS CTXSYS.CONTEXT;


-- Crearea view-urilor 

--  numărul de proiecte pentru fiecare client
CREATE OR REPLACE VIEW view_total_proiecte_client AS
SELECT
    c.client_id,
    c.client_name,
    COUNT(p.project_id) AS nr_total_proiecte
FROM clients c
LEFT JOIN projects p ON c.client_id = p.client_id
GROUP BY c.client_id, c.client_name;

 -- Extragerea angajatilor in fucntie de ore lucrate per luna mai si iunie (se vor afisa toti angjatii chiar daca nu au lucart pe proeicte)
CREATE OR REPLACE VIEW view_ore_lunare_2025 AS
SELECT
    employee_id,
    numele_angajatului,
    NVL(Mai, 0)   AS Mai,
    NVL(Iunie, 0) AS Iunie
FROM (
    SELECT 
        e.employee_id,
        e.name AS numele_angajatului,
        TO_CHAR(ws.work_date, 'YYYY-MM') AS luna_lucru,
        ROUND((EXTRACT(HOUR FROM (ws.end_time - ws.start_time)) * 60 +
               EXTRACT(MINUTE FROM (ws.end_time - ws.start_time))) / 60, 2) AS ore
    FROM work_sessions ws
    JOIN employees e ON ws.employee_id = e.employee_id
    WHERE TO_CHAR(ws.work_date, 'YYYY') = '2025'
)
PIVOT (
    SUM(ore)
    FOR luna_lucru IN (
        '2025-05' AS Mai,
        '2025-06' AS Iunie
    )
);


-- Creaea Materialized view 

--Total ore lucrate de angajati in ultimele 30 zile
CREATE MATERIALIZED VIEW mv_total_hours_last30days
BUILD IMMEDIATE
REFRESH ON DEMAND
AS
SELECT 
    ws.employee_id,
    e.name AS employee_name,
    ROUND(SUM(EXTRACT(HOUR FROM (ws.end_time - ws.start_time)) * 60 + 
               EXTRACT(MINUTE FROM (ws.end_time - ws.start_time))) / 60, 2) AS total_hours,
    COUNT(ws.session_id) AS nr_sesiuni
FROM work_sessions ws
JOIN employees e ON ws.employee_id = e.employee_id
WHERE ws.work_date >= TRUNC(SYSDATE) - 30
GROUP BY ws.employee_id, e.name;

-- Selectrui

----Nr1 
-- numărul total de ore lucrate de fiecare angajat pe fiecare proiect
SELECT
    e.employee_id,
    e.name AS employee_name,
    p.project_id,
    p.project_name,
    NVL(ROUND(SUM(EXTRACT(HOUR FROM (ws.end_time - ws.start_time)) * 60 +
               EXTRACT(MINUTE FROM (ws.end_time - ws.start_time))) / 60, 2),0) AS total_hours_per_project
FROM employees e
JOIN employees_projects ep ON e.employee_id = ep.employee_id
JOIN projects p ON ep.project_id = p.project_id
LEFT JOIN tasks t ON p.project_id = t.project_id AND t.assigned_to = e.employee_id
LEFT JOIN work_sessions ws ON ws.task_id = t.task_id AND ws.employee_id = e.employee_id
GROUP BY e.employee_id, e.name, p.project_id, p.project_name
ORDER BY e.employee_id, p.project_id;


--Nr2 
-- Extaregm top 3 angatati care au lucrat cele mai multe ore 
WITH ore_totale AS (
  SELECT
    e.employee_id,
    e.name AS nume_angajat,
    SUM(
      EXTRACT(DAY FROM (ws.end_time - ws.start_time)) * 24 +
      EXTRACT(HOUR FROM (ws.end_time - ws.start_time)) +
      EXTRACT(MINUTE FROM (ws.end_time - ws.start_time)) / 60 +
      EXTRACT(SECOND FROM (ws.end_time - ws.start_time)) / 3600
    ) AS total_ore
  FROM work_sessions ws
  JOIN employees e ON ws.employee_id = e.employee_id
  GROUP BY e.employee_id, e.name
),
rang_angajati AS (
  SELECT 
    employee_id,
    nume_angajat,
    ROUND(total_ore, 2) AS total_ore,
    RANK() OVER (ORDER BY total_ore DESC) AS pozitie
  FROM ore_totale
)
SELECT *
FROM rang_angajati
WHERE pozitie <= 3
ORDER BY pozitie;

--Nr3
-- angajații care nu au fost alocați la niciun proiect
SELECT 
    e.employee_id,
    e.name AS nume_angajat,
    e.role,
    ep.project_id
FROM 
    employees e
    LEFT JOIN employees_projects ep ON e.employee_id = ep.employee_id
WHERE 
    ep.project_id IS NULL
ORDER BY e.employee_id;

--Nr4 
--Afisarea structurii ierarhice a angajaților pe baza relatiei manager-subordonat
SELECT
    employee_id,
    name AS employee_name,
    manager_id,
    LEVEL AS hierarchy_level
FROM employees
START WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id;


--NR 5 selectii cu json
-- Selecatm angajatii care au skills in python
SELECT * 
FROM employees
WHERE JSON_EXISTS(programming_skills_json, '$.skills[*]?(@ == "Python")');

--se afiseaza fiecare limbaj pentru fiecare angajat
SELECT 
  e.employee_id,
  e.name,
  jt.limbaj
FROM employees e,
     JSON_TABLE(
       e.programming_skills_json,
       '$.skills[*]' COLUMNS (
         limbaj VARCHAR2(50) PATH '$')
     ) jt;




















