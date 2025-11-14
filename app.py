from flask import Flask, render_template, request, redirect
import mysql.connector

app = Flask(__name__)

#Database connection with limited privileges user
conn = mysql.connector.connect(
    host="localhost",
    user="musicuser",
    password="StrongPass123!",
    database="musicdb"
)
cur = conn.cursor(dictionary=True)

# ---------------- HOME PAGE ----------------
@app.route('/')
def home():
    cur.execute("""
        SELECT 
            t.Track_id,
            t.Track_name,
            a.Album_name,
            g.Genre_name,
            CONCAT(s.First_name, ' ', IFNULL(CONCAT(s.Middle_name, ' '), ''), s.Last_name) AS Singer_name,
            s.Singer_id
        FROM Track t
        JOIN Album a ON t.Album_id = a.Album_id
        JOIN Genre g ON t.Genre_id = g.Genre_id
        JOIN Sung_by sb ON t.Track_id = sb.Track_id
        JOIN Singer s ON sb.Singer_id = s.Singer_id
        ORDER BY t.Track_id;
    """)
    tracks = cur.fetchall()
    return render_template('home.html', tracks=tracks)

# ---------------- ADD SINGER ----------------
@app.route('/add_singer', methods=['GET', 'POST'])
def add_singer():
    if request.method == 'POST':
        fname = request.form['fname']
        mname = request.form.get('mname') or None
        lname = request.form['lname']
        cur.execute(
            "INSERT INTO Singer (First_name, Middle_name, Last_name) VALUES (%s, %s, %s)",
            (fname, mname, lname)
        )
        conn.commit()
        return redirect('/')
    return render_template('add_singer.html')

# ---------------- ADD TRACK ----------------
@app.route('/add_track', methods=['GET', 'POST'])
def add_track():
    if request.method == 'POST':
        name = request.form['name']
        lyrics = request.form['lyrics']
        album = request.form['album']
        genre = request.form['genre']
        singer = request.form['singer']
        cur.callproc('sp_AddNewTrackAndLinkSinger', [name, lyrics, album, genre, singer])
        conn.commit()
        return redirect('/')

    cur.execute("SELECT Album_id, Album_name FROM Album")
    albums = cur.fetchall()
    cur.execute("SELECT Genre_id, Genre_name FROM Genre")
    genres = cur.fetchall()
    cur.execute("""
        SELECT Singer_id, CONCAT(First_name, ' ', IFNULL(CONCAT(Middle_name, ' '), ''), Last_name) AS Singer_name 
        FROM Singer
    """)
    singers = cur.fetchall()

    return render_template('add_track.html', albums=albums, genres=genres, singers=singers)

# ---------------- SEARCH TRACKS BY SINGER ----------------
@app.route('/search', methods=['GET', 'POST'])
def search_singer():
    results = []
    search_name = ""

    if request.method == 'POST':
        search_name = request.form['singer_name']
        cur.callproc('sp_SearchTracksBySinger', [search_name])
        for result in cur.stored_results():
            results = result.fetchall()

    return render_template('search.html', results=results, search_name=search_name)

# ---------------- VIEW SINGER AUDIT LOG ----------------
@app.route('/singer_audit')
def singer_audit():
    cur.execute("SELECT * FROM Singer_Audit ORDER BY Change_timestamp DESC")
    logs = cur.fetchall()
    return render_template('singer_audit.html', logs=logs)

# ---------------- EDIT SINGER ----------------
@app.route('/edit_singer/<int:singer_id>', methods=['GET', 'POST'])
def edit_singer(singer_id):
    if request.method == 'POST':
        fname = request.form['fname']
        mname = request.form.get('mname') or None
        lname = request.form['lname']
        cur.execute("""
            UPDATE Singer 
            SET First_name = %s, Middle_name = %s, Last_name = %s 
            WHERE Singer_id = %s
        """, (fname, mname, lname, singer_id))
        conn.commit()
        return redirect('/')

    cur.execute("SELECT * FROM Singer WHERE Singer_id = %s", (singer_id,))
    singer = cur.fetchone()
    return render_template('edit_singer.html', singer=singer)

# ---------------- DELETE SINGER ----------------
@app.route('/delete_singer/<int:singer_id>', methods=['POST'])
def delete_singer(singer_id):
    cur.execute("DELETE FROM Singer WHERE Singer_id = %s", (singer_id,))
    conn.commit()
    return redirect('/')

@app.route('/singers')
def all_singers():
    cur.execute("SELECT * FROM Singer ORDER BY Singer_id DESC")
    singers = cur.fetchall()
    return render_template('singers.html', singers=singers)

# ---------------- RUN APP ----------------
if __name__ == '__main__':
    app.run(debug=True)
