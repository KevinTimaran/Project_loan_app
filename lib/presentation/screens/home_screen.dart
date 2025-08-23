// lib/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:hive/hive.dart'; // Importación necesaria para Hive

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isOptionsExpanded = false;
  late AnimationController _arrowAnimationController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arrowAnimation = Tween(begin: 0.0, end: 0.5).animate(_arrowAnimationController);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _arrowAnimationController.dispose();
    super.dispose();
  }

  void _toggleOptionsExpanded() {
    setState(() {
      _isOptionsExpanded = !_isOptionsExpanded;
      if (_isOptionsExpanded) {
        _arrowAnimationController.forward();
      } else {
        _arrowAnimationController.reverse();
      }
    });
  }

  void _performSearch() {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ClientListScreen(searchTerm: searchTerm),
        ),
      );
    }
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }



  // 💡 Método para borrar todas las bases de datos de Hive con impresiones de depuración
  Future<void> _clearAllHiveBoxes() async {
    try {
      await Hive.deleteBoxFromDisk('clients');
      await Hive.deleteBoxFromDisk('loans');
      
      // 💡 Impresiones de depuración para verificar el estado de las cajas
      print('DEBUG: Borrando caja de clientes...');
      final clientBoxExists = await Hive.boxExists('clients');
      print('DEBUG: ¿La caja de clientes existe después de borrar? $clientBoxExists');
      
      print('DEBUG: Borrando caja de préstamos...');
      final loanBoxExists = await Hive.boxExists('loans');
      print('DEBUG: ¿La caja de préstamos existe después de borrar? $loanBoxExists');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bases de datos de clientes y préstamos borradas correctamente.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al borrar las bases de datos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = Theme.of(context).appBarTheme.backgroundColor!;
    final Color mainGreen = Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}) ?? const Color(0xFF43A047);

    final Color textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final Color iconColor = const Color(0xFF424242);
    final Color alertRed = const Color(0xFFE53935);
    final Color orangeModule = Colors.orange.shade700;
    final Color purpleModule = Colors.purple.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LoanApp - Inicio',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 💡 Botón para borrar todas las bases de datos
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar Borrado General'),
                  content: const Text('Esta acción borrará todos los clientes y préstamos. ¿Estás seguro?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _clearAllHiveBoxes();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Borrar Todo'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Borrar todas las bases de datos (solo para pruebas)',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Bienvenido a LoanApp',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Gestiona tus préstamos, clientes y pagos de manera eficiente.',
                      style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar Cliente rápidamente',
                  hintText: 'Nombre o ID del cliente',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: primaryBlue),
                    onPressed: _performSearch,
                    tooltip: 'Buscar',
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),

            InkWell(
              onTap: _toggleOptionsExpanded,
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Más Opciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                    RotationTransition(
                      turns: _arrowAnimation,
                      child: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _isOptionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: Container(),
                secondChild: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.attach_money,
                      title: 'Gestión de Préstamos',
                      onTap: () {
                        Navigator.of(context).pushNamed('/loanList');
                      },
                      iconColor: mainGreen,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.people,
                      title: 'Gestión de Clientes',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ClientListScreen()),
                        );
                      },
                      iconColor: orangeModule,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.payment,
                      title: 'Registro de Pagos',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Módulo de Pagos en desarrollo.')),
                        );
                      },
                      iconColor: purpleModule,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.money_off,
                      title: 'Gestión de Gastos',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Módulo de Gastos en desarrollo.')),
                        );
                      },
                      iconColor: alertRed,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    final Color textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: iconColor),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}