#ifndef MAINWINDOW_H_
#define MAINWINDOW_H_

#include <QMainWindow>

class QLineEdit;
class QPushButton;
class QTextEdit;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget * parent = nullptr);
    ~MainWindow() override;

private slots:
    void onConnect();
    void onDisconnect();
    void onMicToggle(bool checked);
    void onSpkToggle(bool checked);
    void onCamToggle(bool checked);
    void onMonToggle(bool checked);

private:
    void appendLog(const QString & text);
    void setupUi();

    void * cdc_ = nullptr;

    QLineEdit   * addr_edit_ = nullptr;
    QPushButton * connect_btn_ = nullptr;
    QPushButton * disconnect_btn_ = nullptr;
    QPushButton * mic_btn_ = nullptr;
    QPushButton * spk_btn_ = nullptr;
    QPushButton * cam_btn_ = nullptr;
    QPushButton * mon_btn_ = nullptr;
    QTextEdit   * log_view_ = nullptr;
};

#endif // MAINWINDOW_H_