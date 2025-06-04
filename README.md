# แอปเปรียบเทียบความคุ้มค่าขนมจากแหล่งสินค้าขนมอื่นๆ

ค้นหาขนมชนิดเดียวกันโดยหาว่าสินค้าไหนถูกสุด คำนวณจาก บาท/กรัม อีกทั้งยังสามารถค้นหาสินค้าจากรูปภาพที่เราถ่ายได้

## ภาษาที่ใช้ในการพัฒนาระบบ

Frontend
- Flutter (ใน Android Studio)
ใช้พัฒนา UX/UI และ logic ฝั่งแอปมือถือ (Android/iOS)
- Dart (ภาษาโปรแกรมที่ใช้กับ Flutter)

Backend
- Node.js + Express 
รัน Server เช่น API, การจัดการคำขอ, logic ต่างๆ
- Redis
เก็บ Cache ข้อมูลเพื่อเร่งความเร็วการตอบสนองของ Server และลดค่า Cost
- Google Cloud Vision API
ใช้ดึงข้อความจากภาพ (OCR) จากรูปที่ผู้ใช้ส่งเข้ามาแล้วนำไปค้นหา

Database
- Firebase Authentication
จัดการระบบล็อกอินและลงทะเบียนผู้ใช้ (รองรับ Google Account)
- Firebase Firestore
ฐานข้อมูล NoSQL เก็บข้อมูลผู้ใช้ เช่น รายการบุ๊กมาร์ก, ประวัติการสั่งซื้อ, ข้อมูลสินค้าต่างๆ

![image (1)](https://github.com/user-attachments/assets/2a13ac73-88aa-4fef-b72e-cff93c9fb10a)
