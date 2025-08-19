import 'package:clever_11/presentation/screens/contest/contest_details_screen.dart';
import 'package:clever_11/routes/m11_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_bloc.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_events.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_states.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clever_11/presentation/screens/home/c11_home.dart';

class PaymentScreen extends StatefulWidget {
  final String contestId;
  final Map<String, dynamic> contestData;

  const PaymentScreen(
      {super.key, required this.contestId, required this.contestData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool isExpanded = false;
  bool add_isExpanded = true;

  final TextEditingController _controller = TextEditingController(text: '0');
  bool _isInitialZero = true;
  double currentBalance = 49;
  double unutilised = 19;
  double winnings = 20;
  double bonus = 10;

  final List<Map<String, String>> paymentOffers = [
    {
      "logoPath": "assets/bhim_logo.png",
      "title": "BHIM App",
      "sub_title": "Up to ₹30 Cashback",
    },
    {
      "logoPath": "assets/cred_logo.png",
      "title": "CRED UPI",
      "sub_title": "Up to ₹300 Cashback",
    },
    {
      "logoPath": "assets/cred_logo.png",
      "title": "Amazon Pay UPI",
      "sub_title": "Up to ₹25 Cashback",
    },
    {
      "logoPath": "assets/cred_logo.png",
      "title": "MobiKwik UPI",
      "sub_title": "Flat ₹30 Cashback",
    },
  ];

  double get enteredAmount {
    final text = _controller.text;
    return double.tryParse(text.isEmpty ? "0" : text) ?? 0;
  }

  double get gstPercentage => 28;
  double get gstAmount =>
      (enteredAmount * gstPercentage) / (100 + gstPercentage);
  double get baseAmount => enteredAmount - gstAmount;

  String formatCurrency(double value) => '₹${value.toStringAsFixed(2)}';

  void _setAmount(String amount) {
    setState(() {
      _controller.text = amount;
      _controller.selection =
          TextSelection.fromPosition(TextPosition(offset: amount.length));
    });
  }

  void _clearAmount() {
    _setAmount('0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Add Cash",
          style: TextStyle(color: Colors.white, fontSize: 18.0),
        ),
        backgroundColor: Color(0xFF003FB4),
        iconTheme: IconThemeData(color: Colors.white),
        titleSpacing: 0,
      ),
      bottomNavigationBar: InkWell(
        onTap: () {
          Navigator.pushNamed(context, M11_AppRoutes.c11_payment_options);
        },
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "Add Via UPI",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Google Pay",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.3,
                child: ElevatedButton(
                  onPressed: () async {
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please add some amount'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    // Simulate a successful payment
                    bool paymentSuccess =
                        true; // This should be replaced with actual payment logic
                    if (paymentSuccess) {
                      // Update the user's "My Contests" list
                      context.read<MyContestsBloc>().add(AddContestToMyContests(
                          widget.contestId, widget.contestData));

                      // Show payment success bottom sheet
                      _showPaymentSuccessBottomSheet(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    " ADD  ₹${_controller.text} ",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Current Balance",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  Text("₹49", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (isExpanded) ...[
              SizedBox(height: 12),
              _infoRow("Amount Unutilised", formatCurrency(unutilised)),
              _infoRow("Winnings", formatCurrency(winnings)),
              _infoRow("Discount Bonus", formatCurrency(bonus)),
            ],
            SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: MediaQuery.of(context).size.height * 0.08,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Amount to add",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700)),
                          Row(
                            children: [
                              Text('₹',
                                  style: TextStyle(
                                      fontSize: 20, color: Colors.black87)),
                              SizedBox(width: 5.0),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.25,
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    if (_isInitialZero && value != '0') {
                                      final newValue = value.replaceFirst(
                                          RegExp(r'^0+'), '');
                                      _controller.value = TextEditingValue(
                                          text: newValue,
                                          selection: TextSelection.collapsed(
                                              offset: newValue.length));
                                      _isInitialZero = false;
                                      _setAmount(newValue);
                                    } else if (value.isEmpty) {
                                      _controller.text = '0';
                                      _controller.selection =
                                          TextSelection.collapsed(offset: 1);
                                      _isInitialZero = true;
                                      _setAmount('0');
                                    } else {
                                      _setAmount(value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        height: 25,
                        width: 25,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.clear, size: 16),
                          onPressed: _clearAmount,
                          padding: EdgeInsets.zero,
                          splashRadius: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _amountButton("500"),
                SizedBox(width: 8),
                _amountButton("1000"),
              ],
            ),
            SizedBox(height: 10),
            NotchedContainer(
              child: Column(
                children: [
                  InkWell(
                    onTap: () =>
                        setState(() => add_isExpanded = !add_isExpanded),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Add to Current Balance",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            Text(formatCurrency(enteredAmount),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            SizedBox(width: 8),
                            Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (add_isExpanded) ...[
                    SizedBox(height: 12),
                    divider(),
                    breakdownRow("Deposit Amount (excl. Govt. Tax)",
                        formatCurrency(baseAmount)),
                    breakdownRow(
                        "Govt. Tax (28% GST)", formatCurrency(gstAmount)),
                    divider(),
                    breakdownRow("Total", formatCurrency(enteredAmount),
                        isBold: true),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_offer, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text("Discount Points Worth ",
                            style: TextStyle(fontSize: 14)),
                        Text("₹100.38",
                            style: TextStyle(fontWeight: FontWeight.bold))
                      ],
                    ),
                    divider(),
                    breakdownRow("Add to Current Balance A + B",
                        formatCurrency(enteredAmount),
                        isBold: true),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: Colors.black54)),
              SizedBox(width: 4),
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _amountButton(String amount) {
    return GestureDetector(
      onTap: () => _setAmount(amount),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(amount),
      ),
    );
  }

  Widget breakdownRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget divider() => Divider(color: Colors.grey.shade300, thickness: 1);

  void _showPaymentSuccessBottomSheet(BuildContext context) {
    // Check if this is a wallet add cash scenario or contest payment
    final isWalletAddCash = widget.contestId == 'wallet_add_cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF1E824C), // Deep green
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        if (isWalletAddCash) {
                          // If wallet add cash, go back to home screen
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => M11_Home(),
                            ),
                            (route) => route.isFirst,
                          );
                        } else {
                          // If contest payment, go back to contest details
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ContestDetailsScreen(initialTabIndex: 1),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ),

                // Check Icon with Background Dots
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(Icons.check,
                          color: Color(0xFF1E824C), size: 50),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Title
                const Text(
                  "Payment Successful!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Hooray! You have completed your payment.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                // Amount Paid Card
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "AMOUNT PAID",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "₹${_controller.text}",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          "₹${(double.tryParse(_controller.text) ?? 0) * 0.1} Cashback",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "HOW WAS YOUR PAYMENT EXPERIENCE?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFeedbackButton(
                      icon: Icons.thumb_up,
                      bgColor: Colors.white.withOpacity(0.2),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (isWalletAddCash) {
                          // If wallet add cash, go back to home screen
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => M11_Home(),
                            ),
                            (route) => route.isFirst,
                          );
                        } else {
                          // If contest payment, go back to contest details
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ContestDetailsScreen(initialTabIndex: 1),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildFeedbackButton(
                      icon: Icons.thumb_down,
                      bgColor: Colors.white,
                      iconColor: Colors.red,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (isWalletAddCash) {
                          // If wallet add cash, go back to home screen
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => M11_Home(),
                            ),
                            (route) => route.isFirst,
                          );
                        } else {
                          // If contest payment, go back to contest details
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ContestDetailsScreen(initialTabIndex: 1),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}

class NotchedContainer extends StatelessWidget {
  final Widget child;
  const NotchedContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: NotchClipper(),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: child,
      ),
    );
  }
}

class NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double notchWidth = 20;
    double notchHeight = 10;
    double notchX = size.width * 0.15; // You can adjust this

    Path path = Path();
    path.moveTo(0, notchHeight);
    path.lineTo(notchX, notchHeight);
    path.lineTo(notchX + notchWidth / 2, 0);
    path.lineTo(notchX + notchWidth, notchHeight);
    path.lineTo(size.width, notchHeight);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
