
-- TABLES

-- 1. Create the student directory table

CREATE TABLE IF NOT EXISTS Students (
    student_id INTEGER PRIMARY KEY, 
    first_name TEXT,
    last_name TEXT,
    major TEXT,
    gpa REAL                       
);

-- 2. Create the university course catalog table

CREATE TABLE IF NOT EXISTS Courses (
    course_id INTEGER PRIMARY KEY,  
    course_name TEXT,
    department TEXT,
    credits INTEGER                
);

-- 3. Create the enrollment bridge table linking students to courses

CREATE TABLE IF NOT EXISTS Enrollment (
    enrollment_id INTEGER PRIMARY KEY, 
);

-- QUERIES

-- QUERY 1: Major Popularity Ranking

SELECT 
    major, 
    COUNT(student_id) AS total_students
FROM Students
GROUP BY major
ORDER BY total_students DESC;


-- QUERY 2: Average GPA Performance by Major

SELECT 
    major, 
    ROUND(AVG(gpa), 2) AS average_gpa
FROM Students
GROUP BY major
ORDER BY average_gpa DESC;


-- QUERY 3: Course Difficulty Analysis (The Hardest Classes)

SELECT 
    Courses.course_name,
    Courses.department,
    ROUND(AVG(
        CASE 
            WHEN Enrollment.grade = 'A'  THEN 4.0
            WHEN Enrollment.grade = 'A-' THEN 3.7
            WHEN Enrollment.grade = 'B+' THEN 3.3
            WHEN Enrollment.grade = 'B'  THEN 3.0
            WHEN Enrollment.grade = 'B-' THEN 2.7
            WHEN Enrollment.grade = 'C+' THEN 2.3
            WHEN Enrollment.grade = 'C'  THEN 2.0
            WHEN Enrollment.grade = 'C-' THEN 1.7
            WHEN Enrollment.grade = 'D'  THEN 1.0
            WHEN Enrollment.grade = 'F'  THEN 0.0
            ELSE 2.0 
        END
    ), 2) AS average_course_grade
FROM Enrollment
INNER JOIN Courses ON Enrollment.course_id = Courses.course_id
GROUP BY Courses.course_name, Courses.department
ORDER BY average_course_grade ASC;


-- QUERY 4: High-Headcount Course Bottlenecks

SELECT 
    Courses.course_name, 
    Courses.department, 
    COUNT(Enrollment.student_id) AS total_enrolled
FROM Enrollment
INNER JOIN Courses ON Enrollment.course_id = Courses.course_id
GROUP BY Courses.course_name, Courses.department
HAVING total_enrolled > 25
ORDER BY total_enrolled DESC;


-- QUERY 5: Total Department Revenue Generation

SELECT 
    Courses.department,
    SUM(Courses.credits * 689) AS department_total_revenue
FROM Enrollment
INNER JOIN Courses ON Enrollment.course_id = Courses.course_id
GROUP BY Courses.department
ORDER BY department_total_revenue DESC;
